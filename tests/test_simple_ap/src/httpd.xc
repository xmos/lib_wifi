// Copyright (c) 2011-2016, XMOS Ltd, All rights reserved

#include <string.h>
#include <print.h>
#include "xtcp.h"
#include "httpd.h"
#include "http.h"
#include "debug_print.h"

// Maximum number of concurrent connections
#define NUM_HTTPD_CONNECTIONS 10

// Maximum number of bytes to receive at once
#define RX_BUFFER_SIZE 1518

// Structure to hold HTTP state
typedef struct httpd_state_t {
  int active;                //< Whether this state structure is being used
                             //  for a connection
  int conn_id;               //< The connection id
  char * unsafe dptr;        //< Pointer to the remaining data to send
  int dlen;                  //< The length of remaining data to send
  char * unsafe prev_dptr;   //< Pointer to the previously sent item of data
} httpd_state_t;

httpd_state_t connection_states[NUM_HTTPD_CONNECTIONS];

// Initialize the HTTP state
xtcp_connection_t httpd_init(client xtcp_if i_xtcp)
{
  xtcp_connection_t conn = i_xtcp.socket(XTCP_PROTOCOL_TCP);
  // Listen on the http port
  i_xtcp.listen(conn, 80, XTCP_PROTOCOL_TCP);

  for (int i = 0; i < NUM_HTTPD_CONNECTIONS; i++ ) {
    connection_states[i].active = 0;
    unsafe {
      connection_states[i].dptr = NULL;
    }
  }

  return conn;
}

void print_range(const char * unsafe begin, const char * unsafe end)
{
  for(const char * unsafe itr = begin; itr != end; ++itr) {
    unsafe {debug_printf("%c", *itr);}
  }
}

// Parses a HTTP request for a GET
void parse_http_request(httpd_state_t *hs, char *data, int len)
{
  /*unsafe {parse_http(data, data + len);}*/
  http_t result;
  unsafe {
    {void, void, void, result} = parse_http(data, data + len);
  }

  print_range(result.start_line.request.target.begin, result.start_line.request.target.end);
  debug_printf("\n");
  for (http_field_type_t i = HTTP_FIELD_UNKNOWN; i < HTTP_FIELD_COUNT; ++i) {
    if (result.fields[i].begin != result.fields[i].end) {
      unsafe {print_range(result.fields[i].begin, result.fields[i].end);}
      debug_printf("\n");
    }
  }

  static char memory[1024] = {};

  http_t response;
  response.type = HTTP_RESPONSE;
  response.start_line.response.version = result.start_line.request.version;
  response.start_line.response.status = 200;
  unsafe {
    response.start_line.response.reason.begin = "OK";
    response.start_line.response.reason.end = response.start_line.response.reason.begin + strlen((char*)response.start_line.response.reason.begin);
    response.fields[HTTP_FIELD_CONTENT_TYPE].begin = "text/html";
    response.fields[HTTP_FIELD_CONTENT_TYPE].end = response.fields[HTTP_FIELD_CONTENT_TYPE].begin + strlen((char*)response.fields[HTTP_FIELD_CONTENT_TYPE].begin);
    response.body.begin = "<!DOCTYPE html>\r\n"
      "<html><head><title>Hello world</title></head>\r\n"
      "<body>Hello World!</body></html>";
    response.body.end = response.body.begin + strlen((char*)response.body.begin);

    serialize_http(response, memory, memory + 1024);
  }

  // Return if we have data already
  if (hs->dptr == NULL) {
    // Test if we received a HTTP GET request
    if (
      (HTTP_REQUEST == result.type) &&
      (HTTP_METHOD_GET == result.start_line.request.method) &&
      (1 == result.start_line.request.target.end - result.start_line.request.target.begin) &&
      (0 == memcmp("/", result.start_line.request.target.begin, 1))
    ) {
      // Assign the default page character array as the data to send
      unsafe {
        hs->dptr = memory;
      }
      /*hs->dlen = strlen(page);*/
      hs->dlen = size_http(response);
    } else if (
      (HTTP_REQUEST == result.type) &&
      (HTCPCP_METHOD_BREW == result.start_line.request.method)
    ) {
      debug_printf("BREW\n");
    } else {
      // We did not receive a get request, so do nothing
    }
  }
}

// Send some data back for a HTTP request
void httpd_send(client xtcp_if i_xtcp, xtcp_connection_t &conn)
{
  unsafe {
    struct httpd_state_t *hs = (struct httpd_state_t *) conn.appstate;

    // Check if we have no data to send
    if (hs->dlen == 0 || hs->dptr == NULL) {
      // Close the connection
      printstr("Close\n");
      i_xtcp.close(conn);

    } else {
      // We need to send some new data
      int len = hs->dlen;

      if (len > conn.mss) {
        len = conn.mss;
      }

      printstr("Send ");
      printintln(len);
      i_xtcp.send(conn, (char*)hs->dptr, len);

      hs->prev_dptr = hs->dptr;
      hs->dptr += len;
      hs->dlen -= len;
    }
  }
}


// Receive a HTTP request
void httpd_recv(client xtcp_if i_xtcp, xtcp_connection_t &conn,
                char data[n], const unsigned n)
{
  unsafe {
    struct httpd_state_t *hs = (struct httpd_state_t *) conn.appstate;

    // If we already have data to send, return
    if (hs == NULL || hs->dptr != NULL) {
      return;
    }

    // Otherwise we have data, so parse it
    parse_http_request(hs, &data[0], n);

    httpd_send(i_xtcp, conn);
  }
}


// Setup a new connection
void httpd_init_state(client xtcp_if i_xtcp, xtcp_connection_t &conn)
{
  int i;

  // Try and find an empty connection slot
  for (i = 0; i < NUM_HTTPD_CONNECTIONS; i++) {
    if (!connection_states[i].active) {
      break;
    }
  }

  // If no free connection slots were found, abort the connection
  if (i == NUM_HTTPD_CONNECTIONS) {
    i_xtcp.abort(conn);
    printstr("Abort\n");
  } else {
    printstr("Connect ");
    printintln(i);
    // Otherwise, assign the connection to a slot
    connection_states[i].active = 1;
    connection_states[i].conn_id = conn.id;
    connection_states[i].dptr = NULL;
    i_xtcp.set_appstate(conn, (xtcp_appstate_t) &connection_states[i]);
  }
}


// Free a connection slot, for a finished connection
void httpd_free_state(xtcp_connection_t &conn)
{
  for (int i = 0; i < NUM_HTTPD_CONNECTIONS; i++) {
    if (connection_states[i].conn_id == conn.id) {
      connection_states[i].active = 0;
    }
  }
}


// HTTP event handler
void xhttpd(client xtcp_if i_xtcp)
{
  printstr("**WELCOME TO THE SIMPLE WEBSERVER DEMO**\n");

  // Initiate the HTTP state
  xtcp_connection_t conn = httpd_init(i_xtcp);

  // Loop forever processing TCP events
  while(1) {
    xtcp_connection_t client_conn;
    char rx_buffer[RX_BUFFER_SIZE];
    unsigned data_len;

    select {
      case i_xtcp.event_ready(): {
        const xtcp_event_type_t event = i_xtcp.get_event(client_conn);

        if (client_conn.local_port == 80) {
          // HTTP connections
          switch (event) {
            case XTCP_NEW_CONNECTION:
              httpd_init_state(i_xtcp, client_conn);
              break;
            case XTCP_RECV_DATA:
              data_len = i_xtcp.recv(client_conn, rx_buffer, RX_BUFFER_SIZE);
              httpd_recv(i_xtcp, client_conn, rx_buffer, data_len);
              break;
            case XTCP_SENT_DATA:
              httpd_send(i_xtcp, client_conn);
              break;
            case XTCP_TIMED_OUT:
            case XTCP_ABORTED:
            case XTCP_CLOSED:
                httpd_free_state(client_conn);
                break;
            default:
              break;
          }
        } else {
          // Other connections
          switch(event) {
            case XTCP_IFUP:
              xtcp_ipconfig_t ipconfig;
              i_xtcp.get_ipconfig(ipconfig);

              printstr("IP Address: ");
              printint(ipconfig.ipaddr[0]);printstr(".");
              printint(ipconfig.ipaddr[1]);printstr(".");
              printint(ipconfig.ipaddr[2]);printstr(".");
              printint(ipconfig.ipaddr[3]);printstr("\n");
              break;
            default:
              break;
          }
        }
        break;
      }
    }
  }
}
