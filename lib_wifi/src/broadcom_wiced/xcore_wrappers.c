// Copyright (c) 2015-2017, XMOS Ltd, All rights reserved
#include "wifi.h"
#include "wwd_events.h"
#include "wwd_wifi.h"
#include "wwd_debug.h"
#include "wwd_structures.h"
#include <stddef.h>
#include "xassert.h"
#include "debug_print.h"
#include <string.h>
#include "timer.h"

static int scan_active = 0;

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

static wiced_scan_result_t scan_results[WIFI_MAX_SCAN_RESULTS];
static int record_count;
static wwd_time_t scan_start_time;

// FIXME: give this a proper return type when there is no match
int find_duplicate_scan_result(wiced_scan_result_t *result_ptr) {
  for (int i = 0; i < record_count; i++) {
    // Check if all octets of BSSID match
    if (memcmp(result_ptr->BSSID.octet, scan_results[i].BSSID.octet,
               sizeof(wiced_mac_t))) {
      continue;
    }
    // if they do, check if it's on the same band
    if (result_ptr->band != scan_results[i].band) {
      continue;
    }
    // if it is, check if the channel is the same
    if (result_ptr->channel != scan_results[i].channel) {
      continue;
    }
    // if it is, check if SSID matches
    if ((result_ptr->SSID.length != scan_results[i].SSID.length) ||
        (memcmp(result_ptr->SSID.value, scan_results[i].SSID.value,
                 scan_results[i].SSID.length))) {
      continue;
    }
    // if it does, check the network type matches - warn if not?
    if (result_ptr->bss_type != scan_results[i].bss_type) {
      continue;
    }
    // if it does, check the security type matches
    if (result_ptr->security != scan_results[i].security) {
      continue;
    }
    // Return index of duplicate
    return i;
  }
  return -1; // No match found
}

/*
 * Callback function to handle scan results
 */
void scan_result_handler(wiced_scan_result_t **result_ptr,
                         wiced_scan_status_t status) {
  if (result_ptr != NULL) {
    if (status == WICED_SCAN_INCOMPLETE) {
      int dup_index = find_duplicate_scan_result(*result_ptr);
      if (dup_index != -1) {
        // TODO: update the max data rate, signal strength
        // Clear duplicate
        memset(*result_ptr, 0, sizeof(wiced_scan_result_t));
        // FIXME: clears the last valid result if WIFI_MAX_SCAN_RESULTS is reached
        return;
      }
      ++record_count;
      if (record_count < WIFI_MAX_SCAN_RESULTS) {
        // Bump results_ptr on to point at the next element of scan_results
        *result_ptr = &scan_results[record_count];
      } else if (record_count == WIFI_MAX_SCAN_RESULTS) {
        debug_printf("Aborting scan as maximum number of results reached\n");
        wwd_wifi_abort_scan(); // TODO: check return code
        scan_active = 0;
      }
    }
  } else {
    wwd_time_t scan_end_time = host_rtos_get_time();
    debug_printf("\nScan %s %d milliseconds\n",
      (status == WICED_SCAN_COMPLETED_SUCCESSFULLY) ? "completed in" : "aborted after",
      scan_end_time - scan_start_time);
    for (int i = 0; i < record_count; i++) {
      WPRINT_APP_INFO(("%3d ", i));
      print_scan_result(&scan_results[i]);
    }
    scan_active = 0;
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

wiced_scan_result_t *scan_result_ptr;

size_t xcore_wifi_scan_networks(void) {
  // Clear any previous scan results
  memset(&scan_results, 0, sizeof(wiced_scan_result_t)*record_count);
  record_count = 0;
  scan_result_ptr = &scan_results[record_count];
  scan_start_time = host_rtos_get_time();

  scan_active = 1;
  wwd_wifi_scan( WICED_SCAN_TYPE_ACTIVE, WICED_BSS_TYPE_ANY, NULL, NULL,
    NULL, NULL, CALLBACK_SCAN_RESULT_FUNC, &scan_result_ptr,
    NULL, WWD_STA_INTERFACE);

  while (scan_active) {
    delay_microseconds(10);
  }
  return record_count;
}

int xcore_wifi_get_network_index(const char *name) {
  size_t name_length = strlen(name);
  for (int i = 0; i < record_count; i++) {
    if ((scan_results[i].SSID.length == name_length) &&
        (memcmp(name, scan_results[i].SSID.value, scan_results[i].SSID.length) == 0)) {
      return i;
    }
  }
  return -1;
}

unsigned xcore_wifi_join_network_at_index(size_t index,
                                      uint8_t security_key[],
                                      size_t key_length) {
  wiced_scan_result_t *scan_result_ptr = &scan_results[index];
  unsigned result = wwd_wifi_join(&scan_result_ptr->SSID,
                                  scan_result_ptr->security,
                                  security_key, key_length, NULL);
  debug_printf("Join result = %d\n", result);
  return (WWD_SUCCESS == result);
}

unsigned xcore_wifi_leave_network(void)
{
  return WWD_SUCCESS == wwd_wifi_leave(WWD_STA_INTERFACE);
}

unsigned xcore_wifi_set_radio_mac_address(wiced_mac_t mac_address)
{
  return WWD_SUCCESS == wwd_wifi_set_mac_address(mac_address);
}

unsigned xcore_wifi_ready_to_transceive(void)
{
  return WWD_SUCCESS == wwd_wifi_is_ready_to_transceive(WWD_STA_INTERFACE);
}

unsigned xcore_wifi_start_ap(char * ssid)
{
  wiced_ssid_t wiced_ssid;
  wiced_ssid.length = strlen(ssid);
  memcpy(wiced_ssid.value, ssid, wiced_ssid.length+1);
  const unsigned result = wwd_wifi_start_ap(&wiced_ssid, WICED_SECURITY_OPEN, NULL, 0, 5);
  return (WWD_SUCCESS == result);
}

unsigned xcore_wifi_start_ap_wpa(char * ssid, char * wpa, unsigned length)
{
  wiced_ssid_t wiced_ssid;
  wiced_ssid.length = strlen(ssid);
  memcpy(wiced_ssid.value, ssid, wiced_ssid.length+1);
  const unsigned result = wwd_wifi_start_ap(&wiced_ssid, WICED_SECURITY_WPA_AES_PSK, wpa, length, 5);
  return (WWD_SUCCESS == result);
}

unsigned xcore_wifi_stop_ap(void)
{
  return (WWD_SUCCESS == wwd_wifi_stop_ap());
}

wwd_result_t xcore_wifi_get_radio_mac_address(wiced_mac_t *mac_address) {
  return wwd_wifi_get_mac_address(mac_address, WWD_STA_INTERFACE);
}
