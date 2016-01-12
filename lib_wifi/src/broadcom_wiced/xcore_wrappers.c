// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "wwd_events.h"
#include "wwd_wifi.h"
#include <stddef.h>
#include "xassert.h"

void* wwd_scan_result_handler(const wwd_event_header_t* event_header,
                              const uint8_t* event_data,
                              void* handler_user_data);

void* wwd_handle_apsta_event(const wwd_event_header_t* event_header,
                             const uint8_t* event_data,
                             void* handler_user_data);

void* wiced_join_events_handler(const wwd_event_header_t* event_header,
                                const uint8_t* event_data,
                                void* handler_user_data);

/** TODO: document (brief) */
wwd_event_handler_t* sdpcm_event_handler_wrapper(
    wwd_event_handler_func_selector_t handler,
    const wwd_event_header_t* event_header, const uint8_t* event_data,
    void* handler_user_data) {
  switch (handler) {
    case HANDLER_NULL_FUNC:
      fail("sdpcm_event_handler_wrapper called with null function");
      break;
    case HANDLER_WWD_SCAN_RESULT_FUNC:
      return wwd_scan_result_handler(event_header, event_data,
                                     handler_user_data);
    case HANDLER_WWD_APSTA_EVENT:
      return wwd_handle_apsta_event(event_header, event_data,
                                    handler_user_data);
    case HANDLER_WICED_JOIN_EVENTS:
      return wiced_join_events_handler(event_header, event_data,
                                       handler_user_data);
    default:
      unreachable("sdpcm_event_handler_wrapper called with unknown function");
      break;
  }
  return NULL;
}

/** TODO: document (brief) */
void scan_result_callback_wrapper(
    wiced_scan_result_callback_func_selector_t callback,
    wiced_scan_result_t** result_ptr,
    void* user_data, wiced_scan_status_t status) {
  switch (callback) {
    case CALLBACK_NULL_FUNC:
      fail("scan_result_callback_wrapper called with null function");
      break;
    default:
      unreachable("scan_result_callback_wrapper called with unknown function");
      break;
  }
}
