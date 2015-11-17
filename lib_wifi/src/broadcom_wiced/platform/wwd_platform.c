#include "platform/wwd_platform_interface.h"

wwd_result_t host_platform_init() {
  // TODO: implement
  return WWD_SUCCESS;
}

wwd_result_t host_platform_deinit() {
  // TODO: implement
  return WWD_SUCCESS;
}

void host_platform_reset_wifi(wiced_bool_t reset_asserted) {
  if (reset_asserted == WICED_TRUE) {
    host_platform_power_wifi(WICED_FALSE);
  } else {
    host_platform_power_wifi(WICED_TRUE);
  }
}

void host_platform_power_wifi(wiced_bool_t power_enabled) {
  // TODO: implement
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
