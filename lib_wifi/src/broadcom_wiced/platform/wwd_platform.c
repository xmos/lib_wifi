// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "platform/wwd_platform_interface.h"
#include "wifi_broadcom_wiced.h"

wwd_result_t host_platform_init() {
  // TODO: implement
  return WWD_SUCCESS;
}

wwd_result_t host_platform_deinit() {
  // TODO: implement
  return WWD_SUCCESS;
}

void host_platform_reset_wifi(wiced_bool_t reset_asserted) {
  // If reset asserted, drive the WLAN_RST_N low
  if (reset_asserted == WICED_TRUE) {
    xcore_wiced_drive_reset_line(0);
  } else {
    xcore_wiced_drive_reset_line(1);
  }
}

void host_platform_power_wifi(wiced_bool_t power_enabled) {
  // If power enabled drive WLAN_3V3_EN high
  xcore_wiced_drive_power_line(power_enabled);
}

wwd_result_t host_platform_init_wlan_powersave_clock() {
  // TODO: implement
  return WWD_SUCCESS;
}

wwd_result_t host_platform_deinit_wlan_powersave_clock() {
  // TODO: implement
  return WWD_SUCCESS;
}

uint32_t host_platform_get_cycle_count() {
  return 0; // TODO: xCORE doesn't have a cycle count reg, so return timer val?
}

wiced_bool_t host_platform_is_in_interrupt_context() {
  return WICED_FALSE; // Not using interrupts on the xCORE
}
