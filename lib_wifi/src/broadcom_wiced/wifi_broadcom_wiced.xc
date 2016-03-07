// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "wifi_broadcom_wiced.h"
#include "wifi.h"
#include <stddef.h>
#include <stdint.h>
#include "spi.h"
#include "gpio.h"
#include "xc2compat.h"
#include "xc_broadcom_wiced_includes.h"

#define DEBUG_UNIT WIFI_DEBUG
#include "debug_print.h"
#include "xassert.h"

static const unsigned wifi_bcm_wiced_spi_speed_khz = 100; // TODO: max this out - BCM supports 50MHz
static const spi_mode_t wifi_bcm_wiced_spi_mode = SPI_MODE_1; // XXX: M3 ARM code appears to use SPI_MODE_3, LPC17xx code appears to use SPI_MODE_0...
static const unsigned wifi_bcm_wiced_spi_ss_deassert_ms = 100;
static unsafe client interface spi_master_if i_wifi_bcm_wiced_spi;
static unsigned wifi_bcm_wiced_spi_device_index;

unsafe chanend xcore_wwd_ctrl_external;
unsafe client interface fs_basic_if i_fs_global;

unsafe void xcore_wiced_drive_power_line (uint32_t line_state) {
  i_wifi_bcm_wiced_spi.drive_1bit_of_ss_port(0, 2, line_state);
}

unsafe void xcore_wiced_drive_reset_line(uint32_t line_state) {
  i_wifi_bcm_wiced_spi.drive_1bit_of_ss_port(0, 1, line_state);
}

unsafe void xcore_wiced_spi_transfer(wwd_bus_transfer_direction_t direction,
                                     uint8_t * unsafe buffer,
                                     uint16_t buffer_length) {
  i_wifi_bcm_wiced_spi.begin_transaction(wifi_bcm_wiced_spi_device_index,
                                         wifi_bcm_wiced_spi_speed_khz,
                                         wifi_bcm_wiced_spi_mode);
  if (BUS_READ == direction) {
    // Reading from the bus TO buffer, send zeros as data
    for (int i = 0; i < buffer_length; i++) {
      buffer[i] = i_wifi_bcm_wiced_spi.transfer8(0);
    }
  } else { // Must be BUS_WRITE
    // Writing to the bus FROM buffer, ignore received data
    for (int i = 0; i < buffer_length; i++) {
      i_wifi_bcm_wiced_spi.transfer8(buffer[i]);
    }
  }
  i_wifi_bcm_wiced_spi.end_transaction(wifi_bcm_wiced_spi_ss_deassert_ms);
}

[[combinable]]
static void wifi_broadcom_wiced_spi_internal(
    server interface wifi_hal_if i_hal[n_hal], size_t n_hal,
    server interface wifi_network_config_if i_conf[n_conf], size_t n_conf,
    server interface wifi_network_data_if i_data[n_data], size_t n_data,
    client interface spi_master_if i_spi,
    unsigned spi_device_index) {

  // Save the SPI bus details for use from wwd_spi functions
  unsafe {
    i_wifi_bcm_wiced_spi = i_spi;
  }
  wifi_bcm_wiced_spi_device_index = spi_device_index;

  // Initialise driver and hardware
  debug_printf("Initialising WWD...\n");
  wwd_result_t result = wwd_management_init(WICED_COUNTRY_UNITED_KINGDOM, NULL);
  assert(result == WWD_SUCCESS && msg("WWD initialisation failed!"));
  debug_printf("WWD initialisation complete\n");

  while (1) {
    select {
      case i_hal[int i].get_hardware_status():
        break;

      case i_hal[int i].get_chipset_power_mode():
        break;

      case i_hal[int i].set_chipset_power_mode():
        break;

      case i_hal[int i].get_radio_tx_power():
        break;

      case i_hal[int i].set_radio_tx_power():
        break;

      case i_hal[int i].get_radio_state():
        break;

      case i_hal[int i].set_radio_state():
        break;

      case i_hal[int i].set_antenna_mode():
        break;

      case i_hal[int i].get_channel():
        break;

      case i_hal[int i].set_channel():
        break;
    }
  }
}

[[combinable]]
void wifi_broadcom_wiced_spi(
    server interface wifi_hal_if i_hal[n_hal], size_t n_hal,
    server interface wifi_network_config_if i_conf[n_conf], size_t n_conf,
    server interface wifi_network_data_if i_data[n_data], size_t n_data,
    client interface spi_master_if i_spi,
    unsigned spi_device_index,
    client interface input_gpio_if i_irq,
    client interface fs_basic_if i_fs) {

  chan xcore_wwd_ctrl;

  par {
    // Start the interface task
    {
      unsafe {
        xcore_wwd_ctrl_external = (unsafe chanend)xcore_wwd_ctrl;
        i_fs_global = i_fs;
      }
      wifi_broadcom_wiced_spi_internal(i_hal, n_hal, i_conf, n_conf,
                                       i_data, n_data, i_spi, spi_device_index);
    }

    /* The SDK will expect to start this from the call to wwd_management_init
     * by attempting to spawn an RTOS thread. The xCORE implementation of the
     * WWD RTOS callbacks cannot do this, so the driver task is started
     * immediately and waits to be initialised.
     */
    xcore_wwd(i_irq, xcore_wwd_ctrl);
  }
  // XXX: This while loop is here simply to allow this task to be combinable
  while (1) {
    select {}
  }
}
