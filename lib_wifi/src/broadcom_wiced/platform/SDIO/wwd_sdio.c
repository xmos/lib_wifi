// Copyright (c) 2015-2017, XMOS Ltd, All rights reserved
#include "platform/wwd_bus_interface.h"
#include "platform/wwd_sdio_interface.h"
#include "platform_config.h"

wwd_result_t host_platform_bus_init() {
  // TODO: implement
  return WWD_SUCCESS;
}

wwd_result_t host_platform_bus_deinit() {
  // TODO: implement
  return WWD_SUCCESS;
}

#ifndef WICED_DISABLE_MCU_POWERSAVE
wwd_result_t host_enable_oob_interrupt() {
  // TODO: implement
  return WWD_SUCCESS;
}

uint8_t host_platform_get_oob_interrupt_pin() {
  // TODO: implement
  return WICED_WIFI_OOB_IRQ_GPIO_PIN;
}
#endif

wwd_result_t host_platform_sdio_enumerate() {
  // TODO: implement
  return WWD_SUCCESS;
}

wwd_result_t host_platform_sdio_transfer(wwd_bus_transfer_direction_t direction,
    sdio_command_t command, sdio_transfer_mode_t mode,
    sdio_block_size_t block_size, uint32_t argument, uint32_t* data,
    uint16_t data_size, sdio_response_needed_t response_expected,
    uint32_t* response) {
  // TODO: implement
  return WWD_SUCCESS;
}

void host_platform_enable_high_speed_sdio() {
  // TODO: implement
}

wwd_result_t host_platform_bus_enable_interrupt() {
  // TODO: implement
  return WWD_SUCCESS;
}

wwd_result_t host_platform_bus_disable_interrupt() {
  // TODO: implement
  return WWD_SUCCESS;
}
