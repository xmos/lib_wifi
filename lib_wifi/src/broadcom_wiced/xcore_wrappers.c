// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "wwd_events.h"
#include "wwd_wifi.h"
#include "wwd_wifi.h"
#include "wwd_debug.h"
#include "wwd_structures.h"
#include <stddef.h>
#include "xassert.h"
#include "debug_print.h"

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

void print_scan_result( wiced_scan_result_t *record )
{
    WPRINT_APP_INFO( ( "%5s ", ( record->bss_type == WICED_BSS_TYPE_ADHOC ) ? "Adhoc" : "Infra" ) );
    WPRINT_APP_INFO( ( "%02X:%02X:%02X:%02X:%02X:%02X ", record->BSSID.octet[0], record->BSSID.octet[1], record->BSSID.octet[2], record->BSSID.octet[3], record->BSSID.octet[4], record->BSSID.octet[5] ) );
    WPRINT_APP_INFO( ( " %d ", record->signal_strength ) );
    if ( record->max_data_rate < 100000 )
    {
        WPRINT_APP_INFO( ( " %.1f ", (double) (record->max_data_rate / 1000.0) ) );
    }
    else
    {
        WPRINT_APP_INFO( ( "%.1f ", (double) (record->max_data_rate / 1000.0) ) );
    }
    WPRINT_APP_INFO( ( " %3d  ", record->channel ) );
    WPRINT_APP_INFO( ( "%-15s ", ( record->security == WICED_SECURITY_OPEN             ) ? "Open                 " :
                                 ( record->security == WICED_SECURITY_WEP_PSK          ) ? "WEP                  " :
                                 ( record->security == WICED_SECURITY_WPA_TKIP_PSK     ) ? "WPA  TKIP  PSK       " :
                                 ( record->security == WICED_SECURITY_WPA_AES_PSK      ) ? "WPA  AES   PSK       " :
                                 ( record->security == WICED_SECURITY_WPA_MIXED_PSK    ) ? "WPA  Mixed PSK       " :
                                 ( record->security == WICED_SECURITY_WPA2_AES_PSK     ) ? "WPA2 AES   PSK       " :
                                 ( record->security == WICED_SECURITY_WPA2_TKIP_PSK    ) ? "WPA2 TKIP  PSK       " :
                                 ( record->security == WICED_SECURITY_WPA2_MIXED_PSK   ) ? "WPA2 Mixed PSK       " :
                                 ( record->security == WICED_SECURITY_WPA_TKIP_ENT     ) ? "WPA  TKIP  Enterprise" :
                                 ( record->security == WICED_SECURITY_WPA_AES_ENT      ) ? "WPA  AES   Enterprise" :
                                 ( record->security == WICED_SECURITY_WPA_MIXED_ENT    ) ? "WPA  Mixed Enterprise" :
                                 ( record->security == WICED_SECURITY_WPA2_TKIP_ENT    ) ? "WPA2 TKIP  Enterprise" :
                                 ( record->security == WICED_SECURITY_WPA2_AES_ENT     ) ? "WPA2 AES   Enterprise" :
                                 ( record->security == WICED_SECURITY_WPA2_MIXED_ENT   ) ? "WPA2 Mixed Enterprise" :
                                                                                         "Unknown              " ) );
    WPRINT_APP_INFO( ( " %-32s ", record->SSID.value ) );
    WPRINT_APP_INFO( ( "\n" ) );
}

static int record_count;
static wwd_time_t scan_start_time;

/*
 * Callback function to handle scan results
 */
void scan_result_handler(wiced_scan_result_t **result_ptr, wiced_scan_status_t status) {
  if (result_ptr != NULL) {
    if (status == WICED_SCAN_INCOMPLETE) {
      WPRINT_APP_INFO(("%3d ", record_count));
      print_scan_result(*result_ptr);
      ++record_count;
    }
  } else {
    wwd_time_t scan_end_time = host_rtos_get_time();
    debug_printf("\nScan %s %d milliseconds\n",
      (status == WICED_SCAN_COMPLETED_SUCCESSFULLY) ? "completed in" : "aborted after",
      scan_end_time - scan_start_time);
  }
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
    case CALLBACK_SCAN_RESULT_FUNC:
      scan_result_handler(result_ptr, status);
      break;
    default:
      unreachable("scan_result_callback_wrapper called with unknown function");
      break;
  }
}

static wiced_scan_result_t scan_result;

void xcore_wifi_scan_networks() {
  const uint16_t chlist[] = { 1,2,3,4,5,6,7,8,9,10,11,12,13,14,0 };
  const wiced_scan_extended_params_t extparam = { 5, 110, 110, 50 };
  wiced_scan_result_t *scan_result_ptr = &scan_result;

  record_count = 0;
  scan_start_time = host_rtos_get_time();

  wwd_wifi_scan( WICED_SCAN_TYPE_ACTIVE, WICED_BSS_TYPE_ANY, NULL, NULL,
    chlist, &extparam, CALLBACK_SCAN_RESULT_FUNC, &scan_result_ptr,
    NULL, WWD_STA_INTERFACE);
}
