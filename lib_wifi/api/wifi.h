// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef __wifi_h__
#define __wifi_h__

#include <xs1.h>
#include <stddef.h>
#include "spi.h"
#include "gpio.h"
#include "filesystem.h"

/** Module HAL - similar to smi.h?
 * TODO: document
 */
typedef interface wifi_hal_if {

  /** TODO: document */
  void get_hardware_status();

  /** TODO: document */
  void get_chipset_power_mode();

  /** TODO: document */
  void set_chipset_power_mode(); // required?

  /** TODO: document */
  void get_radio_tx_power();

  /** TODO: document */
  void set_radio_tx_power();

  /** TODO: document */
  void get_radio_state();

  /** TODO: document */
  void set_radio_state(); // on/off

  /** TODO: document */
  void set_antenna_mode(); //auto select/manual ant1/manual ant2/etc.

  /** TODO: document */
  void get_channel(); // move to wifi_network_config_if?

  /** TODO: document */
  void set_channel(); // move to wifi_network_config_if?

} wifi_hal_if;

/** WiFi/application configuration interface - ethernet.h equivalent
 * TODO: document
 */
typedef interface wifi_network_config_if {

  /** TODO: document */
  void get_mac_address();

  /** TODO: document */
  void set_mac_address();

  /** TODO: document */
  void get_link_state();

  /** TODO: document */
  void set_link_state(); // up/down

  /** TODO: document */
  void set_networking_mode(); // AP, AD Hoc, client, etc.

  // Client mode functions
  /** TODO: document */
  void scan_for_networks();

  /** TODO: document */
  void join_network(unsigned ssid); // XXX: need to pass in password/key

  /** TODO: document */
  void leave_network(unsigned ssid); // can you be connected to more than one?

  // TODO: MAC address filtering/ethertype filtering/

  // TODO: Functions to configure roaming, getting signal strengths, etc.

  // Soft AP functions
  // TODO: Functions to handle clients connecting when we're an AP...
} wifi_network_config_if;

/** WiFi/xtcp data interface - mii.h equivalent
 * TODO: document
 */
typedef interface wifi_network_data_if {

  /** TODO: document */
  void receive_packet();

  /** TODO: document */
  void send_packet();

  // TODO: Add function to notify clients of received packets
} wifi_network_data_if;

void wifi_broadcom_wiced_spi(
    server interface wifi_hal_if i_hal[n_hal], size_t n_hal,
    server interface wifi_network_config_if i_conf[n_conf], size_t n_conf,
    server interface wifi_network_data_if i_data[n_data], size_t n_data,
    client interface spi_master_if i_spi,
    unsigned spi_device_index,
    client interface input_gpio_if i_irq,
    client interface fs_basic_if i_fs);

// NOTE: named to allow future SDIO support: wifi_broadcom_wiced_sdio()

#endif // __wifi_h__
