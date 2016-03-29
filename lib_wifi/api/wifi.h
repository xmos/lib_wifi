// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef __wifi_h__
#define __wifi_h__

#ifndef WIFI_MAX_SCAN_RESULTS
/** TODO: document */
#define WIFI_MAX_SCAN_RESULTS 50
#endif

#ifndef WIFI_MAX_KEY_LENGTH
/** TODO: document */
#define WIFI_MAX_KEY_LENGTH 50
#endif

#ifdef __XC__

#include <xs1.h>
#include <stddef.h>
#include "xc_broadcom_wiced_includes.h"
#include "xtcp.h"
#include "ethernet.h"
#include "spi.h"
#include "gpio.h"
#include "filesystem.h"

/** TODO: document */
typedef enum {
  WIFI_SUCCESS, ///< TODO: document
  WIFI_ERROR    ///< TODO: document
} wifi_res_t;

/** Module HAL - similar to smi.h?
 * TODO: document
 */
typedef interface wifi_hal_if {

  /** TODO: document */
  void init_radio();

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
  wifi_res_t get_mac_address(uint8_t mac_address[6]);

  /** TODO: document */
  void set_mac_address();

  /** TODO: document */
  ethernet_link_state_t get_link_state();

  /** TODO: document */
  void set_link_state(ethernet_link_state_t state); // up/down

  /** TODO: document */
  void set_networking_mode(); // AP, AD Hoc, client, etc.

  // Client mode functions
  /** TODO: document */
  void scan_for_networks();

  /** TODO: document */
  size_t get_num_networks();

  /** TODO: document */
  const wiced_ssid_t * unsafe get_network_ssid(size_t index);

  /** TODO: document */
  void join_network(size_t index, uint8_t security_key[key_length],
                    size_t key_length);

  /** TODO: document */
  void leave_network(size_t index); // can you be connected to more than one?

  // TODO: MAC address filtering/ethertype filtering/

  // TODO: Functions to configure roaming, getting signal strengths, etc.

  // Soft AP functions
  // TODO: Functions to handle clients connecting when we're an AP...
} wifi_network_config_if;

void wifi_broadcom_wiced_spi(
    server interface wifi_hal_if i_hal[n_hal], size_t n_hal,
    server interface wifi_network_config_if i_conf[n_conf], size_t n_conf,
    server interface xtcp_pbuf_if i_data,
    client interface spi_master_if i_spi,
    unsigned spi_device_index,
    client interface input_gpio_if i_irq,
    client interface fs_basic_if i_fs);

// NOTE: named to allow future SDIO support: wifi_broadcom_wiced_sdio()

/** TODO: document */
void xtcp_lwip_wifi(chanend xtcp[n], size_t n,
                    client interface wifi_hal_if i_wifi_hal,
                    client interface wifi_network_config_if i_wifi_config,
                    client interface xtcp_pbuf_if i_wifi_data,
                    xtcp_ipconfig_t &ipconfig);

#endif // __XC__

#endif // __wifi_h__
