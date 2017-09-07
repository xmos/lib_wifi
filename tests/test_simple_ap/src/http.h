#ifndef _HTTP_H_
#define _HTTP_H_

#define PARSE_T(X) {int, const char * unsafe, const char * unsafe, X}

typedef enum http_method_t {
  HTTP_METHOD_UNKNOWN,
  HTTP_METHOD_GET,
  HTTP_METHOD_HEAD,
  HTTP_METHOD_POST,
  HTTP_METHOD_PUT,
  HTTP_METHOD_DELETE,
  HTTP_METHOD_TRACE,
  HTTP_METHOD_OPTIONS,
  HTTP_METHOD_CONNECT,
  HTTP_METHOD_PATCH,
  HTCPCP_METHOD_BREW,
  HTCPCP_METHOD_PROPFIND,
  HTCPCP_METHOD_WHEN
} http_method_t;

typedef enum http_version_t {
  HTTP_VERSION_UNKNOWN,
  HTTP_VERSION_1_0,
  HTTP_VERSION_1_1,
  HTCPCP_VERSION_1_0
} http_version_t;

typedef enum http_field_type_t {
  HTTP_FIELD_UNKNOWN,
  HTTP_FIELD_ACCEPT,
  HTTP_FIELD_ACCEPT_CHARSET,
  HTTP_FIELD_ACCEPT_ENCODING,
  HTTP_FIELD_ACCEPT_LANGUAGE,
  HTTP_FIELD_ACCEPT_DATETIME,
  HTTP_FIELD_AUTHORIZATION,
  HTTP_FIELD_CACHE_CONTROL,
  HTTP_FIELD_CONNECTION,
  HTTP_FIELD_COOKIE,
  HTTP_FIELD_CONTENT_LENGTH,
  HTTP_FIELD_CONTENT_MD5,
  HTTP_FIELD_CONTENT_TYPE,
  HTTP_FIELD_DATE,
  HTTP_FIELD_EXPECT,
  HTTP_FIELD_FORWARDED,
  HTTP_FIELD_FROM,
  HTTP_FIELD_HOST,
  HTTP_FIELD_IF_MATCH,
  HTTP_FIELD_IF_MODIFIED_SINCE,
  HTTP_FIELD_IF_NONE_MATCH,
  HTTP_FIELD_IF_RANGE,
  HTTP_FIELD_IF_UNMODIFIED_SINCE,
  HTTP_FIELD_MAX_FORWARDS,
  HTTP_FIELD_ORIGIN,
  HTTP_FIELD_PRAGMA,
  HTTP_FIELD_PROXY_AUTHORIZATION,
  HTTP_FIELD_RANGE,
  HTTP_FIELD_REFERER,
  HTTP_FIELD_TE,
  HTTP_FIELD_USER_AGENT,
  HTTP_FIELD_UPGRADE,
  HTTP_FIELD_VIA,
  HTTP_FIELD_WARNING,

  HTTP_FIELD_ACCESS_CONTROL_ALLOW_ORIGIN,
  HTTP_FIELD_ACCESS_CONTROL_ALLOW_CREDENTIALS,
  HTTP_FIELD_ACCESS_CONTROL_EXPOSE_HEADERS,
  HTTP_FIELD_ACCESS_CONTROL_MAX_AGE,
  HTTP_FIELD_ACCESS_CONTROL_ALLOW_METHODS,
  HTTP_FIELD_ACCESS_CONTROL_ALLOW_HEADERS,
  HTTP_FIELD_ACCEPT_PATCH,
  HTTP_FIELD_ACCEPT_RANGES,
  HTTP_FIELD_AGE,
  HTTP_FIELD_ALLOW,
  HTTP_FIELD_ALT_SVC,
  HTTP_FIELD_CONTENT_DISPOSITION,
  HTTP_FIELD_CONTENT_ENCODING,
  HTTP_FIELD_CONTENT_LANGUAGE,
  HTTP_FIELD_CONTENT_LOCATION,
  HTTP_FIELD_CONTENT_RANGE,
  HTTP_FIELD_ETAG,
  HTTP_FIELD_EXPIRES,
  HTTP_FIELD_LAST_MODIFIED,
  HTTP_FIELD_LINK,
  HTTP_FIELD_LOCATION,
  HTTP_FIELD_P3P,
  HTTP_FIELD_PROXY_AUTHENTICATE,
  HTTP_FIELD_PUBLIC_KEY_PINS,
  HTTP_FIELD_RETRY_AFTER,
  HTTP_FIELD_SERVER,
  HTTP_FIELD_SET_COOKIE,
  HTTP_FIELD_STRICT_TRANSPORT_SECURITY,
  HTTP_FIELD_TRAILER,
  HTTP_FIELD_TRANSFER_ENCODING,
  HTTP_FIELD_TK,
  HTTP_FIELD_VARY,
  HTTP_FIELD_WWW_AUTHENTICATE,
  HTTP_FIELD_X_FRAME_OPTIONS,

  HTTP_FIELD_ACCEPT_ADDITIONS,

  HTTP_FIELD_COUNT
} http_field_type_t;

typedef enum http_status_code_t {
  HTTP_STATUS_UNKNOWN
} http_status_code_t;

typedef struct string_view_t {
  const char * unsafe begin;
  const char * unsafe end;
} string_view_t;

typedef struct http_request_t {
  http_method_t method;
  string_view_t target;
  http_version_t version;
} http_request_t;

typedef struct http_response_t {
  http_version_t version;
  http_status_code_t status;
  string_view_t reason;
} http_response_t;

typedef struct http_field_t {
  http_field_type_t name;
  string_view_t value;
} http_field_t;

typedef struct http_t {
  http_request_t request;
  string_view_t fields[HTTP_FIELD_COUNT];
  string_view_t body;
} http_t;

/** Parse an HTTP message.
 *
 * @param begin The beginning of the input range.
 * @param end The end of the input range.
 *
 * @returns a parsed http_t.
 */
PARSE_T(http_t) parse_http(const char * unsafe begin, const char * unsafe end);
char * unsafe serialize_http(const http_t & http, char * unsafe begin, char * unsafe end);

#endif