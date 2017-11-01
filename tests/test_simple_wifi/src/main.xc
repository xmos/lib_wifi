// Copyright (c) 2015-2017, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <platform.h>
#include <quadflash.h>
#include <print.h>
#include <string.h>
#include <stdlib.h>

#include "wifi.h"
#include "gpio.h"
#include "qspi_flash_storage_media.h"
#include "filesystem.h"
#include "xtcp.h"

#include "parse_command_line.h"
#include "debug_print.h"
#include "xassert.h"

#define ETHERNET_SMI_PHY_ADDRESS (0)

out port p_lpo_sleep_clk = on tile[0]: XS1_PORT_4D; // Bit 3

wifi_spi_ports p_wifi_spi = {
  on tile[1]: XS1_PORT_1G,
  on tile[1]: XS1_PORT_1C,
  on tile[1]: XS1_PORT_1B,
  on tile[1]: XS1_PORT_1F,
  0, // CS on bit 0 of port 4E
  on tile[1]: XS1_CLKBLK_3,
  1, // 100/4 (2*2n)
  1000,
  0
};

// Input port used for IRQ interrupt line
in port p_irq = on tile[1]: XS1_PORT_4B;

fl_QSPIPorts qspi_flash_ports = {
  PORT_SQI_CS,
  PORT_SQI_SCLK,
  PORT_SQI_SIO,
  on tile[0]: XS1_CLKBLK_1
};

/* IP Config - change this to suit your network
 * Leave with all 0 values to use DHCP/AutoIP
 */
xtcp_ipconfig_t ipconfig = {
  { 0, 0, 0, 0 }, // ip address (e.g. 192,168,0,2)
  { 0, 0, 0, 0 }, // netmask (e.g. 255,255,255,0)
  { 0, 0, 0, 0 }  // gateway (e.g. 192,168,0,1)
};

void filesystem_tasks(server interface fs_basic_if i_fs[1])
{
  interface fs_storage_media_if i_media;
  fl_QuadDeviceSpec qspi_spec = FL_QUADDEVICE_ISSI_IS25LQ032B;

  par {
    [[distribute]] qspi_flash_fs_media(i_media, qspi_flash_ports,
                                       qspi_spec, 512);
    filesystem_basic(i_fs, 1, FS_FORMAT_FAT12, i_media);
  }
}

void configure_wifi(client interface wifi_network_config_if i_conf)
{
  char network_name[SSID_NAME_SIZE] = "test_network";
  char key[] = "test_password";

  i_conf.scan_for_networks();
  const unsigned result = i_conf.join_network_by_name(network_name, key, strlen(key));
  debug_printf("Joining network %s with result %d\n", network_name, result);
}

typedef enum {
  CONFIG_XTCP = 0,
  CONFIG_XSCOPE,
  NUM_CONFIG
} config_interfaces;

enum eth_clients {
  ETH_TO_XTCP,
  NUM_ETH_CLIENTS
};

enum cfg_clients {
  CFG_TO_XTCP,
  CFG_TO_PHY_DRIVER,
  NUM_CFG_CLIENTS
};

int main(void)
{
  interface wifi_hal_if i_hal[1];
  interface wifi_network_config_if i_conf[NUM_CONFIG];
  interface xtcp_pbuf_if i_data;
  interface input_gpio_if i_inputs[1];
  interface fs_basic_if i_fs[1];
  xtcp_if i_xtcp[1];
  ethernet_cfg_if i_cfg[NUM_CFG_CLIENTS];
  ethernet_rx_if i_rx[NUM_ETH_CLIENTS];
  ethernet_tx_if i_tx[NUM_ETH_CLIENTS];

  par {
    on tile[1]: configure_wifi(i_conf[CONFIG_XSCOPE]);
    on tile[1]: wifi_broadcom_wiced_builtin_spi(i_hal, 1, i_conf, NUM_CONFIG, i_data, p_wifi_spi, i_inputs[0], i_fs[0]);
    on tile[1]: input_gpio_with_events(i_inputs, 1, p_irq, null);
    on tile[1]: wifi_ethernet_mac(i_rx[0], i_tx[0], i_hal[0], i_data);
    on tile[1]: ethernet_wifi_cfg(i_conf[CONFIG_XTCP], i_cfg[CFG_TO_XTCP]);
    on tile[0]: xtcp_lwip(i_xtcp, 1, null, i_cfg[CFG_TO_XTCP], i_rx[ETH_TO_XTCP], i_tx[ETH_TO_XTCP], null, ETHERNET_SMI_PHY_ADDRESS, null, null, ipconfig);
    on tile[0]: filesystem_tasks(i_fs);
  }

  return 0;
}
