#include "http.h"
#include <string.h>
#include <ctype.h>
#include <xassert.h>
#include "debug_print.h"

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
 * @returns a parsed character.
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
    {status, begin, end, result.request} = parse_http_request(begin, end);
    if (status) {
      {status, begin, end, void} = parse_http_fields(begin, end, result.fields);
      if (status) {
        return {1, begin, end, result};
      }
    }

    return {0, begin, end, result};
  }
}

static char * unsafe serialize_char(const char value, char * unsafe begin, char * unsafe end)
{
  xassert(begin < end);
  unsafe {*begin = value;}
  return begin;
}

static char * unsafe serialize_string(const char * unsafe string, char * unsafe begin, char * unsafe end)
{
  unsafe {
    const unsigned int length = strlen((void*)string);
    xassert(begin + length < end);
    memcpy(begin, string, length);
    return begin + length;
  }
}

static char * unsafe serialize_string_view(const string_view_t & view, char * unsafe begin, char * unsafe end)
{
  xassert(view.end - view.begin < end - begin);
  unsafe {
    const unsigned int length = view.end - view.begin;
    memcpy(begin, view.begin, length);
    return begin + length;
  }
}

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

static char * unsafe serialize_http_target(const string_view_t & target, char * unsafe begin, char * unsafe end)
{
  return serialize_string_view(target, begin, end);

  return begin;
}

static char * unsafe serialize_http_request(const http_request_t & request, char * unsafe begin, char * unsafe end)
{
  begin = serialize_http_method(request.method, begin, end);
  begin = serialize_char(' ', begin, end);
  begin = serialize_http_target(request.target, begin, end);
  begin = serialize_char(' ', begin, end);
  begin = serialize_http_version(request.version, begin, end);
  return begin;
}

static char * unsafe serialize_http_field_name(const http_field_type_t field_type, char * unsafe begin, char * unsafe end)
{
  for (int i = 0; i < 67; ++i) {
    if (field_lut[i].value == field_type) {
      return serialize_string(field_lut[i].key, begin, end);
    }
  }

  return begin;
}

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

char * unsafe serialize_http(const http_t & http, char * unsafe begin, char * unsafe end)
{
  begin = serialize_http_request(http.request, begin, end);
  begin = serialize_http_fields(http, begin, end);
  begin = serialize_string("\r\n", begin, end);
  return serialize_string_view(http.body, begin, end);
}
