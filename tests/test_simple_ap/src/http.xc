#include "http.h"
#include <string.h>
#include <ctype.h>
#include <xassert.h>

const static struct {
  const char key[33];
  const http_field_type_t value;
} field_lut[] = {
  {"Accept",HTTP_FIELD_ACCEPT},
  {"Accept-Charset",HTTP_FIELD_ACCEPT_CHARSET},
  {"Accept-Encoding",HTTP_FIELD_ACCEPT_ENCODING},
  {"Accept-Language",HTTP_FIELD_ACCEPT_LANGUAGE},
  {"Accept-Datetime",HTTP_FIELD_ACCEPT_DATETIME},
  {"Authorization",HTTP_FIELD_AUTHORIZATION},
  {"Cache-Control",HTTP_FIELD_CACHE_CONTROL},
  {"Connection",HTTP_FIELD_CONNECTION},
  {"Cookie",HTTP_FIELD_COOKIE},
  {"Content-Length",HTTP_FIELD_CONTENT_LENGTH},
  {"Content-MD5",HTTP_FIELD_CONTENT_MD5},
  {"Content-Type",HTTP_FIELD_CONTENT_TYPE},
  {"Date",HTTP_FIELD_DATE},
  {"Expect",HTTP_FIELD_EXPECT},
  {"Forwarded",HTTP_FIELD_FORWARDED},
  {"From",HTTP_FIELD_FROM},
  {"Host",HTTP_FIELD_HOST},
  {"If-Match",HTTP_FIELD_IF_MATCH},
  {"If-Modified-Since",HTTP_FIELD_IF_MODIFIED_SINCE},
  {"If-None-Match",HTTP_FIELD_IF_NONE_MATCH},
  {"If-Range",HTTP_FIELD_IF_RANGE},
  {"If-Unmodified-Since",HTTP_FIELD_IF_UNMODIFIED_SINCE},
  {"Max-Forwards",HTTP_FIELD_MAX_FORWARDS},
  {"Origin",HTTP_FIELD_ORIGIN},
  {"Pragma",HTTP_FIELD_PRAGMA},
  {"Proxy-Authorization",HTTP_FIELD_PROXY_AUTHORIZATION},
  {"Range",HTTP_FIELD_RANGE},
  {"Referer",HTTP_FIELD_REFERER},
  {"TE",HTTP_FIELD_TE},
  {"User-Agent",HTTP_FIELD_USER_AGENT},
  {"Upgrade",HTTP_FIELD_UPGRADE},
  {"Via",HTTP_FIELD_VIA},
  {"Warning",HTTP_FIELD_WARNING},
  {"Access-Control-Allow-Origin",HTTP_FIELD_ACCESS_CONTROL_ALLOW_ORIGIN},
  {"Access-Control-Allow-Credentials",HTTP_FIELD_ACCESS_CONTROL_ALLOW_CREDENTIALS},
  {"Access-Control-Expose-Headers",HTTP_FIELD_ACCESS_CONTROL_EXPOSE_HEADERS},
  {"Access-Control-Max-Age",HTTP_FIELD_ACCESS_CONTROL_MAX_AGE},
  {"Access-Control-Allow-Methods",HTTP_FIELD_ACCESS_CONTROL_ALLOW_METHODS},
  {"Access-Control-Allow-Headers",HTTP_FIELD_ACCESS_CONTROL_ALLOW_HEADERS},
  {"Accept-Patch",HTTP_FIELD_ACCEPT_PATCH},
  {"Accept-Ranges",HTTP_FIELD_ACCEPT_RANGES},
  {"Age",HTTP_FIELD_AGE},
  {"Allow",HTTP_FIELD_ALLOW},
  {"Alt-Svc",HTTP_FIELD_ALT_SVC},
  {"Content-Disposition",HTTP_FIELD_CONTENT_DISPOSITION},
  {"Content-Encoding",HTTP_FIELD_CONTENT_ENCODING},
  {"Content-Language",HTTP_FIELD_CONTENT_LANGUAGE},
  {"Content-Location",HTTP_FIELD_CONTENT_LOCATION},
  {"Content-Range",HTTP_FIELD_CONTENT_RANGE},
  {"ETag",HTTP_FIELD_ETAG},
  {"Expires",HTTP_FIELD_EXPIRES},
  {"Last-Modified",HTTP_FIELD_LAST_MODIFIED},
  {"Link",HTTP_FIELD_LINK},
  {"Location",HTTP_FIELD_LOCATION},
  {"P3P",HTTP_FIELD_P3P},
  {"Proxy-Authenticate",HTTP_FIELD_PROXY_AUTHENTICATE},
  {"Public-Key-Pins",HTTP_FIELD_PUBLIC_KEY_PINS},
  {"Retry-After",HTTP_FIELD_RETRY_AFTER},
  {"Server",HTTP_FIELD_SERVER},
  {"Set-Cookie",HTTP_FIELD_SET_COOKIE},
  {"Strict-Transport-Security",HTTP_FIELD_STRICT_TRANSPORT_SECURITY},
  {"Trailer",HTTP_FIELD_TRAILER},
  {"Transfer-Encoding",HTTP_FIELD_TRANSFER_ENCODING},
  {"Tk",HTTP_FIELD_TK},
  {"Vary",HTTP_FIELD_VARY},
  {"WWW-Authenticate",HTTP_FIELD_WWW_AUTHENTICATE},
  {"X-Frame-Options",HTTP_FIELD_X_FRAME_OPTIONS},
};

/** Parse a single character from the input range.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 * @param value The character to "parse".
 *
 * @returns the parsed character.
 */
PARSE_T(char) static parse_char(const char * unsafe begin, const char * unsafe end, const char value)
{
  unsafe {
    if (value == *begin) {
      return {1, begin + 1, end, value};
    } else {
      return {0, begin, end, 0};
    }
  }
}

/** Parse a single character from the input range.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 *
 * @returns the parsed character.
 */
PARSE_T(char) static parse_any_char(const char * unsafe begin, const char * unsafe end)
{
  unsafe {
    return {1, begin + 1, end, *begin};
  };
}

/** Parse a string until a given sentinel value is reached.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 * @param sentinel The value which is considered the "end" of the string.
 *
 * @returns a parsed string view.
 */
PARSE_T(string_view_t) static parse_string_until(const char * unsafe begin, const char * unsafe end, const char sentinel)
{
  string_view_t result = {begin};
  unsafe {
    // While we haven't reached the end of the input range.
    for (const char * unsafe itr = begin; end != itr; ++itr) {
      if (sentinel == *itr) {
        result.end = itr;
        // If we have found the sentinel, return the string_view_t.
        return {1, itr, end, result};
      }
    }
  }

  // Failed to find the sentinel.
  return {0, begin, end, result};
}

/** Parse 0, or more, consecutive whitespace characters.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 *
 * @returns a parsed count of whitespace characters.
 */
PARSE_T(int) static parse_whitespace(const char * unsafe begin, const char * unsafe end)
{
  unsafe {
    // While we haven't reached the end of the input range.
    for (const char * unsafe itr = begin; end != itr; ++itr) {
      if (!isspace(*itr)) {
        // If a non-whitespace character has been found, return the count.
        return {1, itr, end, itr - begin};
      }
    }
  }

  return {1, end, end, end - begin};
}

/** Parse an HTTP method.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 *
 * @returns a parsed http_method_t.
 */
PARSE_T(http_method_t) static parse_http_method(const char * unsafe begin, const char * unsafe end)
{
  // TODO: Better search strategy?
  unsafe {
    if (0 == memcmp(begin, "GET", 3)) {
      return {1, begin + 3, end, HTTP_METHOD_GET};
    } else if (0 == memcmp(begin, "HEAD", 4)) {
      return {1, begin + 4, end, HTTP_METHOD_HEAD};
    } else if (0 == memcmp(begin, "POST", 4)) {
      return {1, begin + 4, end, HTTP_METHOD_POST};
    } else if (0 == memcmp(begin, "PUT", 3)) {
      return {1, begin + 3, end, HTTP_METHOD_PUT};
    } else if (0 == memcmp(begin, "DELETE", 6)) {
      return {1, begin + 6, end, HTTP_METHOD_DELETE};
    } else if (0 == memcmp(begin, "TRACE", 5)) {
      return {1, begin + 5, end, HTTP_METHOD_TRACE};
    } else if (0 == memcmp(begin, "OPTIONS", 7)) {
      return {1, begin + 7, end, HTTP_METHOD_OPTIONS};
    } else if (0 == memcmp(begin, "CONNECT", 7)) {
      return {1, begin + 7, end, HTTP_METHOD_CONNECT};
    } else if (0 == memcmp(begin, "PATCH", 5)) {
      return {1, begin + 5, end, HTTP_METHOD_PATCH};
    } else if (0 == memcmp(begin, "BREW", 4)) {
      return {1, begin + 4, end, HTCPCP_METHOD_BREW};
    } else if (0 == memcmp(begin, "PROPFIND", 8)) {
      return {1, begin + 8, end, HTCPCP_METHOD_PROPFIND};
    } else if (0 == memcmp(begin, "WHEN", 4)) {
      return {1, begin + 4, end, HTCPCP_METHOD_WHEN};
    } else {
      return {0, begin, end, HTTP_METHOD_UNKNOWN};
    }
  }
}

/** Parse a supported HTTP method.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 *
 * @returns a parsed http_version_t.
 */
PARSE_T(http_version_t) static parse_http_version(const char * unsafe begin, const char * unsafe end)
{
  unsafe {
    if (0 == memcmp(begin, "HTTP/1.0", 8)) {
      return {1, begin + 8, end, HTTP_VERSION_1_0};
    } else if (0 == memcmp(begin, "HTTP/1.1", 8)) {
      return {1, begin + 8, end, HTTP_VERSION_1_1};
    } else if (0 == memcmp(begin, "HTCPCP/1.0", 10)) {
      return {1, begin + 10, end, HTCPCP_VERSION_1_0};
    } else {
      return {0, begin, end, HTTP_VERSION_UNKNOWN};
    }
  }
}

/** Parse an HTTP target, eg /index.html.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 *
 * @returns a parsed string_view_t which contains the target string.
 */
PARSE_T(string_view_t) static parse_http_target(const char * unsafe begin, const char * unsafe end)
{
  int status;
  string_view_t result;
  {status, begin, end, result} = parse_string_until(begin, end, ' ');
  return {status, begin, end, result};
}

/** Parse an HTTP request.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 *
 * @returns a parsed http_request_t.
 */
PARSE_T(http_request_t) static parse_http_request(const char * unsafe begin, const char * unsafe end)
{
  int status = 0;
  http_request_t result;

  {status, begin, end, result.method} = parse_http_method(begin, end);
  if (status) {
    {status, begin, end, void} = parse_char(begin, end, ' ');
    if (status) {
      {status, begin, end, result.target} = parse_http_target(begin, end);
      if (status) {
        {status, begin, end, void} = parse_char(begin, end, ' ');
        if (status) {
          {status, begin, end, result.version} = parse_http_version(begin, end);
          if (status) {
            {status, begin, end, void} = parse_char(begin, end, '\r');
            if (status) {
              {status, begin, end, void} = parse_char(begin, end, '\n');
              if (status) {
                return {1, begin, end, result};
              }
            }
          }
        }
      }
    }
  }

  return {0, begin, end, result};
}

/** Parse an HTTP status code.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 *
 * @returns the HTTP status code.
 */
PARSE_T(http_status_code_t) static parse_http_status_code(const char * unsafe begin, const char * unsafe end)
{
  int status;
  http_status_code_t result;
  char c[3];
  {status, begin, end, c[0]} = parse_any_char(begin, end);
  if (status) {
    c[0] -= '0';
    {status, begin, end, c[1]} = parse_any_char(begin, end);
    if (status) {
      c[1] -= '0';
      {status, begin, end, c[2]} = parse_any_char(begin, end);
      if (status && isdigit(c[0]) && isdigit(c[1]) && isdigit(c[2])) {
        c[2] -= '0';
        return {1, begin, end, c[0] * 100 + c[1] * 10 + c[2]};
      }
    }
  }

  return {0, begin, end, result};
}

/** Parse an HTTP response.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 *
 * @returns the HTTP response.
 */
PARSE_T(http_response_t) static parse_http_response(const char * unsafe begin, const char * unsafe end)
{
  int status;
  http_response_t result;
  {status, begin, end, result.version} = parse_http_version(begin, end);
  if (status) {
    {status, begin, end, void} = parse_char(begin, end, ' ');
    if (status) {
      {status, begin, end, result.status} = parse_http_status_code(begin, end);
      if (status) {
        {status, begin, end, void} = parse_char(begin, end, ' ');
        if (status) {
          {status, begin, end, result.reason} = parse_string_until(begin, end, '\r');
          if (status) {
            {status, begin, end, void} = parse_char(begin, end, '\r');
            if (status) {
              {status, begin, end, void} = parse_char(begin, end, '\n');
              if (status) {
                return {1, begin, end, result};
              }
            }
          }
        }
      }
    }
  }

  return {0, begin, end, result};
}

/** Parse an HTTP field name.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 *
 * @returns a parsed http_field_type_t.
 */
PARSE_T(http_field_type_t) static parse_http_field_name(const char * unsafe begin, const char * unsafe end)
{
  // TODO: improve search algorithm. Current is O(n).
  unsafe {
    // For each element in the field look-up table.
    for (int i = 0; i < 67; ++i) {
      // Does it match?
      if (strlen(field_lut[i].key) == (end - begin)) {
        if (0 == memcmp(begin, field_lut[i].key, end - begin)) {
          return {1, end, end, field_lut[i].value};
        }
      }
    }
  }

  // We found an unknown field.
  return {1, begin, end, HTTP_FIELD_UNKNOWN};
}

/** Parse an HTTP field.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 *
 * @returns a parsed http_field_t.
 */
PARSE_T(http_field_t) static parse_http_field(const char * unsafe begin, const char * unsafe end)
{
  int status;
  http_field_t result;
  string_view_t field_data;
  const char * unsafe _end = end;
  const char * unsafe _begin = begin;

  {status, _begin, _end, field_data} = parse_string_until(_begin, _end, '\r');
  if (status) {
    {status, _begin, _end, void} = parse_char(_begin, _end, '\r');
    if (status) {
      {status, _begin, _end, void} = parse_char(_begin, _end, '\n');
      if (status && field_data.begin != field_data.end) {
        string_view_t field_name;
        {status, begin, end, field_name} = parse_string_until(field_data.begin, field_data.end, ':');
        if (status) {
          {status, begin, end, void} = parse_char(begin, end, ':');
          if (status) {
            {status, result.value.begin, result.value.end, void} = parse_whitespace(begin, end);
            if (status) {
              {status, void, void, result.name} = parse_http_field_name(field_name.begin, field_name.end);
              if (status) {
                return {1, _begin, _end, result};
              }
            }
          }
        }
      } else {
        result.name        = HTTP_FIELD_UNKNOWN;
        result.value.begin = NULL;
        result.value.end   = NULL;
        return {status, _begin, _end, result};
      }
    }
  }

  return {0, _begin, _end, result};
}

/** Parse all HTTP fields.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 * @param result The array where the fields are stored
 *
 * @returns 0
 */
PARSE_T(int) static parse_http_fields(const char * unsafe begin, const char * unsafe end, string_view_t result[HTTP_FIELD_COUNT])
{
  int status = 1;
  http_field_t field;
  unsafe {
    do {
      {status, begin, end, field} = parse_http_field(begin, end);
      if (status) {
        result[field.name] = field.value;
      }
    } while (status && field.value.begin != field.value.end);
  }

  return {status, begin, end, 0};
}

/** Parse an HTTP message.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 *
 * @returns a parsed http_t.
 */
PARSE_T(http_t) parse_http(const char * unsafe begin, const char * unsafe end)
{
  int status;
  http_t result;

  unsafe {
    {status, begin, end, result.start_line.request} = parse_http_request(begin, end);
    if (status) {
      result.type = HTTP_REQUEST;
      {status, begin, end, void} = parse_http_fields(begin, end, result.fields);
      if (status) {
        return {1, begin, end, result};
      }
    } else {
      {status, begin, end, result.start_line.response} = parse_http_response(begin, end);
      if (status) {
        result.type = HTTP_RESPONSE;
        {status, begin, end, void} = parse_http_fields(begin, end, result.fields);
        if (status) {
          return {1, begin, end, result};
        }
      }
    }

    return {0, begin, end, result};
  }
}

/** Serialize a single character into the output range.
 *
 * @param value The character to "serialize".
 * @param begin The beginning of the output range.
 * @param end The end of the output range.
 *
 * @returns The new beginning of the output range.
 */
static char * unsafe serialize_char(const char value, char * unsafe begin, char * unsafe end)
{
  xassert(begin < end);
  unsafe {
    *begin = value;
    return begin + 1;
  }
}

/** Serialize a C-style string into the output range.
 *
 * @param string The C-style string.
 * @param begin The beginning of the output range.
 * @param end The end of the output range.
 *
 * @returns The new beginning of the output range.
 */
static char * unsafe serialize_string(const char * unsafe string, char * unsafe begin, char * unsafe end)
{
  unsafe {
    const unsigned int length = strlen((const char*)string);
    xassert(begin < end && begin + length < end);
    memcpy(begin, string, length);
    return begin + length;
  }
}

/** Serialize a string view into the output range.
 *
 * @param view The string view to serialize
 * @param begin The beginning of the output range.
 * @param end The end of the output range.
 *
 * @returns The new beginning of the output range.
 */
static char * unsafe serialize_string_view(const string_view_t & view, char * unsafe begin, char * unsafe end)
{
  xassert(&begin && &end && &view && begin < end && view.begin < view.end && view.end - view.begin < end - begin);
  unsafe {
    const unsigned int length = view.end - view.begin;
    memcpy(begin, view.begin, length);
    return begin + length;
  }
}

/** Serialize an HTTP method into the output range.
 *
 * @param method The HTTP method.
 * @param begin The beginning of the output range.
 * @param end The end of the output range.
 *
 * @returns The new beginning of the output range.
 */
static char * unsafe serialize_http_method(const http_method_t method, char * unsafe begin, char * unsafe end)
{
  switch(method) {
    case HTTP_METHOD_GET:
      return serialize_string("GET", begin, end);
    case HTTP_METHOD_HEAD:
      return serialize_string("HEAD", begin, end);
    case HTTP_METHOD_POST:
      return serialize_string("POST", begin, end);
    case HTTP_METHOD_PUT:
      return serialize_string("PUT", begin, end);
    case HTTP_METHOD_DELETE:
      return serialize_string("DELETE", begin, end);
    case HTTP_METHOD_TRACE:
      return serialize_string("TRACE", begin, end);
    case HTTP_METHOD_OPTIONS:
      return serialize_string("OPTIONS", begin, end);
    case HTTP_METHOD_CONNECT:
      return serialize_string("CONNECT", begin, end);
    case HTTP_METHOD_PATCH:
      return serialize_string("PATCH", begin, end);
    case HTCPCP_METHOD_BREW:
      return serialize_string("BREW", begin, end);
    case HTCPCP_METHOD_PROPFIND:
      return serialize_string("PROPFIND", begin, end);
    case HTCPCP_METHOD_WHEN:
      return serialize_string("WHEN", begin, end);
  }

  return begin;
}

/** Serialize an HTTP version into the output range.
 *
 * @param version The HTTP version.
 * @param begin The beginning of the output range.
 * @param end The end of the output range.
 *
 * @returns The new beginning of the output range.
 */
static char * unsafe serialize_http_version(const http_version_t version, char * unsafe begin, char * unsafe end)
{
  switch (version) {
    case HTTP_VERSION_1_0:
      return serialize_string("HTTP/1.0", begin, end);
    case HTTP_VERSION_1_1:
      return serialize_string("HTTP/1.1", begin, end);
    case HTCPCP_VERSION_1_0:
      return serialize_string("HTCPCP/1.0", begin, end);
  }

  return begin;
}

/** Serialize an HTTP target string into the output range.
 *
 * @param target The HTTP target.
 * @param begin The beginning of the output range.
 * @param end The end of the output range.
 *
 * @returns The new beginning of the output range.
 */
static char * unsafe serialize_http_target(const string_view_t & target, char * unsafe begin, char * unsafe end)
{
  return serialize_string_view(target, begin, end);

  return begin;
}

/** Serialize an HTTP request line into the output range.
 *
 * @param request The HTTP request.
 * @param begin The beginning of the output range.
 * @param end The end of the output range.
 *
 * @returns The new beginning of the output range.
 */
static char * unsafe serialize_http_request(const http_request_t & request, char * unsafe begin, char * unsafe end)
{
  begin = serialize_http_method(request.method, begin, end);
  begin = serialize_char(' ', begin, end);
  begin = serialize_http_target(request.target, begin, end);
  begin = serialize_char(' ', begin, end);
  begin = serialize_http_version(request.version, begin, end);
  return begin;
}

/** Serialize an HTTP status code into the output range.
 *
 * @param status The HTTP status code.
 * @param begin The beginning of the output range.
 * @param end The end of the output range.
 *
 * @returns The new beginning of the output range.
 */
static char * unsafe serialize_status_code(const http_status_code_t status, char * unsafe begin, char * unsafe end)
{
  xassert(100 <= status && status <= 999); // status is a 3 digit base-10 number.
  const char c[3] = {
    '0' + (status % 10),
    '0' + ((status / 10) % 10),
    '0' + ((status / 100) % 10)
  };

  begin = serialize_char(c[2], begin, end);
  begin = serialize_char(c[1], begin, end);
  return serialize_char(c[0], begin, end);
}

/** Serialize an HTTP request line into the output range.
 *
 * @param request The HTTP request.
 * @param begin The beginning of the output range.
 * @param end The end of the output range.
 *
 * @returns The new beginning of the output range.
 */
static char * unsafe serialize_http_response(const http_response_t & request, char * unsafe begin, char * unsafe end)
{
  begin = serialize_http_version(request.version, begin, end);
  begin = serialize_char(' ', begin, end);
  begin = serialize_status_code(request.status, begin, end);
  begin = serialize_char(' ', begin, end);
  begin = serialize_string_view(request.reason, begin, end);
  return serialize_string("\r\n", begin, end);
}

/** Serialize an HTTP field name into the output range.
 *
 * @param field_type The HTTP field type.
 * @param begin The beginning of the output range.
 * @param end The end of the output range.
 *
 * @returns The new beginning of the output range.
 */
static char * unsafe serialize_http_field_name(const http_field_type_t field_type, char * unsafe begin, char * unsafe end)
{
  for (int i = 0; i < 67; ++i) {
    if (field_lut[i].value == field_type) {
      return serialize_string(field_lut[i].key, begin, end);
    }
  }

  return begin;
}

/** Serialze HTTP field into the output range.
 *
 * @param http The HTTP object, from which the fields are taken.
 * @param begin The beginning of the output range.
 * @param end The end of the output range.
 *
 * @returns The new beginning of the output range.
 */
static char * unsafe serialize_http_fields(const http_t & http, char * unsafe begin, char * unsafe end)
{
  for (int i = 0; i < HTTP_FIELD_COUNT; ++i) {
    if (http.fields[i].begin != http.fields[i].end) {
      begin = serialize_http_field_name(i, begin, end);
      begin = serialize_string(": ", begin, end);
      begin = serialize_string_view(http.fields[i], begin, end);
      begin = serialize_string("\r\n", begin, end);
    }
  }

  return serialize_string("\r\n", begin, end);
}

/** Serialize an HTTP packet into the output range.
 *
 * @param http The HTTP object.
 * @param begin The beginning of the output range.
 * @param end The end of the output range.
 *
 * @returns The new beginning of the output range.
 */
char * unsafe serialize_http(const http_t & http, char * unsafe begin, char * unsafe end)
{
  if (HTTP_REQUEST == http.type) {
    begin = serialize_http_request(http.start_line.request, begin, end);
  } else if (HTTP_RESPONSE) {
    begin = serialize_http_response(http.start_line.response, begin, end);
  }
  begin = serialize_http_fields(http, begin, end);
  return serialize_string_view(http.body, begin, end);
}

/** Calculate the length of a string_view_t
 *
 * @param view The given string_view_t.
 *
 * @returns the length of the given string_view_t in bytes.
 */
static unsigned int size_string_view(const string_view_t & view)
{
  return view.end - view.begin;
}

/** Calculate the length of an HTTP method.
 *
 * @param method The given HTTP method.
 *
 * @returns the length of the given HTTP method.
 */
static unsigned int size_http_method(const http_method_t method)
{
  switch(method) {
    case HTTP_METHOD_UNKNOWN:
      return 0;
    case HTTP_METHOD_GET:
      return 3;
    case HTTP_METHOD_HEAD:
      return 4;
    case HTTP_METHOD_POST:
      return 4;
    case HTTP_METHOD_PUT:
      return 3;
    case HTTP_METHOD_DELETE:
      return 6;
    case HTTP_METHOD_TRACE:
      return 5;
    case HTTP_METHOD_OPTIONS:
      return 7;
    case HTTP_METHOD_CONNECT:
      return 7;
    case HTTP_METHOD_PATCH:
      return 5;
    case HTCPCP_METHOD_BREW:
      return 4;
    case HTCPCP_METHOD_PROPFIND:
      return 8;
    case HTCPCP_METHOD_WHEN:
      return 4;
  }
}

/** Calculate the length of an HTTP version string.
 *
 * @param version The given HTTP version string.
 *
 * @returns the length of the given HTTP version string in bytes.
 */
static unsigned int size_http_version(const http_version_t version)
{
  switch(version) {
    case HTTP_VERSION_UNKNOWN:
      return 0;
    case HTTP_VERSION_1_0:
      return 8;
    case HTTP_VERSION_1_1:
      return 8;
    case HTCPCP_VERSION_1_0:
      return 10;
  }
}

/** Calculate the length of an HTTP target string.
 *
 * @param view The given HTTP target string.
 *
 * @returns the length of the given HTTP target string in bytes.
 */
static unsigned int size_http_target(const string_view_t & view)
{
  return size_string_view(view);
}

/** Calculate the length of an HTTP request.
 *
 * @param request The given HTTP request.
 *
 * @returns the length of the given HTTP request in bytes.
 */
static unsigned int size_http_request(const http_request_t & request)
{
  return size_http_method(request.method) + 1 +
    size_string_view(request.target) + 1 +
    size_http_version(request.version) + 2;
}

/** Calculate the length of an HTTP status code.
 *
 * @param status_code The given HTTP status code.
 *
 * @returns the length of the given HTTP status code in bytes.
 */
static unsigned int size_http_status_code(const http_status_code_t status_code)
{
  return 3;
}

/** Calculate the length of an HTTP response.
 *
 * @param response The given HTTP response.
 *
 * @returns the length of the given HTTP response in bytes.
 */
static unsigned int size_http_response(const http_response_t & response)
{
  return size_http_version(response.version) + 1 +
    size_http_status_code(response.status) + 1 +
    size_string_view(response.reason) + 2;
}

/** Calculate the length of an HTTP field name.
 *
 * @param field_type The given HTTP field name.
 *
 * @returns the length of the given HTTP field name in bytes.
 */
static unsigned int size_http_field_name(const http_field_type_t field_type)
{
  switch(field_type) {
    case HTTP_FIELD_UNKNOWN:
      return 0;
    case HTTP_FIELD_ACCEPT:
      return 6;
    case HTTP_FIELD_ACCEPT_CHARSET:
      return 14;
    case HTTP_FIELD_ACCEPT_ENCODING:
      return 15;
    case HTTP_FIELD_ACCEPT_LANGUAGE:
      return 15;
    case HTTP_FIELD_ACCEPT_DATETIME:
      return 15;
    case HTTP_FIELD_AUTHORIZATION:
      return 13;
    case HTTP_FIELD_CACHE_CONTROL:
      return 13;
    case HTTP_FIELD_CONNECTION:
      return 10;
    case HTTP_FIELD_COOKIE:
      return 6;
    case HTTP_FIELD_CONTENT_LENGTH:
      return 14;
    case HTTP_FIELD_CONTENT_MD5:
      return 11;
    case HTTP_FIELD_CONTENT_TYPE:
      return 12;
    case HTTP_FIELD_DATE:
      return 4;
    case HTTP_FIELD_EXPECT:
      return 6;
    case HTTP_FIELD_FORWARDED:
      return 9;
    case HTTP_FIELD_FROM:
      return 4;
    case HTTP_FIELD_HOST:
      return 4;
    case HTTP_FIELD_IF_MATCH:
      return 8;
    case HTTP_FIELD_IF_MODIFIED_SINCE:
      return 17;
    case HTTP_FIELD_IF_NONE_MATCH:
      return 13;
    case HTTP_FIELD_IF_RANGE:
      return 8;
    case HTTP_FIELD_IF_UNMODIFIED_SINCE:
      return 19;
    case HTTP_FIELD_MAX_FORWARDS:
      return 12;
    case HTTP_FIELD_ORIGIN:
      return 6;
    case HTTP_FIELD_PRAGMA:
      return 6;
    case HTTP_FIELD_PROXY_AUTHORIZATION:
      return 19;
    case HTTP_FIELD_RANGE:
      return 5;
    case HTTP_FIELD_REFERER:
      return 7;
    case HTTP_FIELD_TE:
      return 2;
    case HTTP_FIELD_USER_AGENT:
      return 10;
    case HTTP_FIELD_UPGRADE:
      return 7;
    case HTTP_FIELD_VIA:
      return 3;
    case HTTP_FIELD_WARNING:
      return 7;
    case HTTP_FIELD_ACCESS_CONTROL_ALLOW_ORIGIN:
      return 27;
    case HTTP_FIELD_ACCESS_CONTROL_ALLOW_CREDENTIALS:
      return 32;
    case HTTP_FIELD_ACCESS_CONTROL_EXPOSE_HEADERS:
      return 29;
    case HTTP_FIELD_ACCESS_CONTROL_MAX_AGE:
      return 22;
    case HTTP_FIELD_ACCESS_CONTROL_ALLOW_METHODS:
      return 28;
    case HTTP_FIELD_ACCESS_CONTROL_ALLOW_HEADERS:
      return 28;
    case HTTP_FIELD_ACCEPT_PATCH:
      return 12;
    case HTTP_FIELD_ACCEPT_RANGES:
      return 13;
    case HTTP_FIELD_AGE:
      return 3;
    case HTTP_FIELD_ALLOW:
      return 5;
    case HTTP_FIELD_ALT_SVC:
      return 7;
    case HTTP_FIELD_CONTENT_DISPOSITION:
      return 19;
    case HTTP_FIELD_CONTENT_ENCODING:
      return 16;
    case HTTP_FIELD_CONTENT_LANGUAGE:
      return 16;
    case HTTP_FIELD_CONTENT_LOCATION:
      return 16;
    case HTTP_FIELD_CONTENT_RANGE:
      return 13;
    case HTTP_FIELD_ETAG:
      return 4;
    case HTTP_FIELD_EXPIRES:
      return 7;
    case HTTP_FIELD_LAST_MODIFIED:
      return 13;
    case HTTP_FIELD_LINK:
      return 4;
    case HTTP_FIELD_LOCATION:
      return 8;
    case HTTP_FIELD_P3P:
      return 3;
    case HTTP_FIELD_PROXY_AUTHENTICATE:
      return 18;
    case HTTP_FIELD_PUBLIC_KEY_PINS:
      return 15;
    case HTTP_FIELD_RETRY_AFTER:
      return 11;
    case HTTP_FIELD_SERVER:
      return 6;
    case HTTP_FIELD_SET_COOKIE:
      return 10;
    case HTTP_FIELD_STRICT_TRANSPORT_SECURITY:
      return 25;
    case HTTP_FIELD_TRAILER:
      return 7;
    case HTTP_FIELD_TRANSFER_ENCODING:
      return 17;
    case HTTP_FIELD_TK:
      return 2;
    case HTTP_FIELD_VARY:
      return 4;
    case HTTP_FIELD_WWW_AUTHENTICATE:
      return 16;
    case HTTP_FIELD_X_FRAME_OPTIONS:
      return 15;
    case HTTP_FIELD_ACCEPT_ADDITIONS:
      return 16;
  }
}

/** Calculate the length of the fields of an HTTP object.
 *
 * @param http The given HTTP object.
 *
 * @returns the length of the HTTP fields in bytes.
 */
static unsigned int size_http_fields(const http_t & http)
{
  unsigned int result = 0;

  for (int i = 0; i < HTTP_FIELD_COUNT; ++i) {
    if (http.fields[i].begin != http.fields[i].end) {
      result += size_http_field_name(i);
      result += size_string_view(http.fields[i]);
      result += 4;
    }
  }

  return result + 2;
}

/** Calculate the length of an HTTP object
 *
 * @param http The given HTTP object.
 *
 * @returns the length of the given HTTP object in bytes.
 */
unsigned int size_http(const http_t & http)
{
  if (HTTP_REQUEST == http.type) {
    return size_http_request(http.start_line.request) +
      size_http_fields(http) +
      size_string_view(http.body);
  } else if (HTTP_RESPONSE == http.type) {
    return size_http_response(http.start_line.response) +
      size_http_fields(http) +
      size_string_view(http.body);
  } else {
    return 0;
  }
}
