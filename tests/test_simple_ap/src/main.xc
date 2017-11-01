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

#include "debug_print.h"
#include "xassert.h"
#include "dhcp_server.h"
#include "dns_server.h"
#include "httpd.h"

#define USE_CMD_LINE_ARGS 1
#define USE_UDP_REFLECTOR 1

#define RX_BUFFER_SIZE 2000
#define BROADCAST_INTERVAL 600000000
#define BROADCAST_PORT 15534
#define BROADCAST_MSG "XMOS Broadcast\n"
#define INIT_VAL -1

enum flag_status {TRUE=1, FALSE=0};

out port p_lpo_sleep_clk = on tile[0]: XS1_PORT_4D; // Bit 3

wifi_spi_ports p_wifi_spi = {
  on tile[1]: XS1_PORT_1N,
  on tile[1]: XS1_PORT_1M,
  on tile[1]: XS1_PORT_1L,
  on tile[1]: XS1_PORT_4E,
  0, // CS on bit 0 of port 4E
  on tile[1]: XS1_CLKBLK_3,
  1, // 100/4 (2*2n)
  1000,
  0
};

// Input port used for IRQ interrupt line
in port p_irq = on tile[1]: XS1_PORT_4F;

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
  { 192, 168,   0,   1 }, // ip address (e.g. 192,168,0,2)
  { 255, 255, 255,   0 }, // netmask (e.g. 255,255,255,0)
  {   0,   0,   0,   0 }  // gateway (e.g. 192,168,0,1)
};

void filesystem_tasks(server interface fs_basic_if i_fs[])
{
  interface fs_storage_media_if i_media;
  fl_QuadDeviceSpec qspi_spec = FL_QUADDEVICE_ISSI_IS25LQ016B;

  par {
    [[distribute]] qspi_flash_fs_media(i_media, qspi_flash_ports,
                                       qspi_spec, 512);
    filesystem_basic(i_fs, 1, FS_FORMAT_FAT12, i_media);
  }
}

void sleep_clock_gen()
{
  // 32.768kHz to bit 3 of p_lpo_sleep_clk
  timer t;
  unsigned delay;
  unsigned clk_signal = 0x8; // Bit 3
  t :> delay;
  delay += 1526;
  unsigned counts[] = {1526, 1526, 1526, 1525, 1526, 1526, 1525};
  unsigned i = 0;
  while (1) {
    select {
      case t when timerafter(delay) :> void:
        p_lpo_sleep_clk <: clk_signal;
        clk_signal = (~clk_signal) & 0x8;
        delay += counts[i];
        i = (i+1) % 6;
        break;
    }
  }
}

void setup_wifi(client interface wifi_network_config_if i_conf)
{
  char network_name[SSID_NAME_SIZE] = "VDA_AP";
  char key[] = "some_key_123";
  unsigned result = i_conf.start_ap_wpa(network_name, strlen(network_name), key, strlen(key));
  debug_printf("Starting AP %s with result %d\n", network_name, result);
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

#define ETHERNET_SMI_PHY_ADDRESS (0)

[[combinable]]
void dns_handler(server dns_if i_dns)
{
  while(1) {
    select {
      case i_dns.question(const dns_question_type_t _a, const dns_question_class_t _b, const char name[n], const unsigned n) -> dns_ip4_addr_t result:
        result = 0x0100A8C0;
        break;
    }
  }
}

int main(void) {
  interface wifi_hal_if i_hal[1];
  interface wifi_network_config_if i_conf[NUM_CONFIG];
  interface xtcp_pbuf_if i_data;
  interface input_gpio_if i_inputs[1];
  interface fs_basic_if i_fs[1];
  xtcp_if i_xtcp[3];
  dns_if i_dns;
  ethernet_cfg_if i_cfg[NUM_CFG_CLIENTS];
  ethernet_rx_if i_rx[NUM_ETH_CLIENTS];
  ethernet_tx_if i_tx[NUM_ETH_CLIENTS];

  par {
    on tile[1]: setup_wifi(i_conf[CONFIG_XSCOPE]);
    on tile[1]: wifi_broadcom_wiced_builtin_spi(i_hal, 1, i_conf, NUM_CONFIG, i_data, p_wifi_spi, i_inputs[0], i_fs[0]);
    on tile[1]: input_gpio_with_events(i_inputs, 1, p_irq, null);
    on tile[1]: wifi_ethernet_mac(i_rx[0], i_tx[0], i_hal[0], i_data);
    on tile[1]: ethernet_wifi_cfg(i_conf[CONFIG_XTCP], i_cfg[CFG_TO_XTCP]);
    on tile[0]: xtcp_lwip(i_xtcp, 3, null, i_cfg[CFG_TO_XTCP], i_rx[ETH_TO_XTCP], i_tx[ETH_TO_XTCP], null, ETHERNET_SMI_PHY_ADDRESS, null, null, ipconfig);
    on tile[0]: filesystem_tasks(i_fs);
    on tile[0]: dhcp_server(i_xtcp[0]);
    on tile[0]: dns_server(i_dns, i_xtcp[1]);
    on tile[0]: xhttpd(i_xtcp[2]);
    on tile[0]: dns_handler(i_dns);
  }

  return 0;
}
