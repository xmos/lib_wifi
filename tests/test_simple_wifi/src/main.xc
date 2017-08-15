// Copyright (c) 2015-2017, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <platform.h>
#include <xscope.h>
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

#define USE_CMD_LINE_ARGS 1
#define USE_SLEEP_CLOCK 0
#define USE_UDP_REFLECTOR 1

#define RX_BUFFER_SIZE 2000
#define INCOMING_PORT 15533
#define BROADCAST_INTERVAL 600000000
#define BROADCAST_PORT 15534
#define BROADCAST_ADDR {255,255,255,255}
#define BROADCAST_MSG "XMOS Broadcast\n"
#define INIT_VAL -1

enum flag_status {TRUE=1, FALSE=0};

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

void filesystem_tasks(server interface fs_basic_if i_fs[]) {
  interface fs_storage_media_if i_media;
  fl_QuadDeviceSpec qspi_spec = FL_QUADDEVICE_ISSI_IS25LQ032B;

  par {
    [[distribute]] qspi_flash_fs_media(i_media, qspi_flash_ports,
                                       qspi_spec, 512);
    filesystem_basic(i_fs, 1, FS_FORMAT_FAT12, i_media);
  }
}

void sleep_clock_gen() {
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

/** Simple UDP reflection thread.
 *
 * This thread does two things:
 *
 *   - Reponds to incoming packets on port INCOMING_PORT and
 *     with a packet with the same content back to the sender.
 *   - Periodically sends out a fixed packet to a broadcast IP address.
 *
 */
void udp_reflect(client xtcp_if i_xtcp)
{
  xtcp_connection_t conn = i_xtcp.socket(XTCP_PROTOCOL_TCP);
  timer tmr;
  unsigned int time;
  char rx_buffer[RX_BUFFER_SIZE];

  // Instruct server to listen and create new connections on the incoming port
  i_xtcp.listen(conn, INCOMING_PORT, XTCP_PROTOCOL_TCP);

  tmr :> time;
  while (1) {
    select {
    case i_xtcp.event_ready():
      xtcp_connection_t conn_tmp;
      const xtcp_event_type_t event = i_xtcp.get_event(conn_tmp);

      switch (event)
      {
        case XTCP_IFUP:
          debug_printf("IFUP\n");
          break;

        case XTCP_IFDOWN:
          debug_printf("IFDOWN\n");
          break;

        case XTCP_NEW_CONNECTION:
          debug_printf("New connection to listening port: %d\n", conn_tmp.local_port);
          break;

        case XTCP_RECV_DATA:
          const int result = i_xtcp.recv(conn_tmp, rx_buffer, RX_BUFFER_SIZE);

          if (result > 0) {
            i_xtcp.send(conn_tmp, rx_buffer, result);
          } else {
            i_xtcp.close(conn_tmp);
          }
          break;

        case XTCP_TIMED_OUT:
        case XTCP_ABORTED:
        case XTCP_CLOSED:
          debug_printf("Closed connection: %d\n", conn.id);
          i_xtcp.close(conn_tmp);
          break;
        default:
          break;
      }
      break;

    // This is the periodic case, it occurs every BROADCAST_INTERVAL
    // timer ticks
    case tmr when timerafter(time + BROADCAST_INTERVAL) :> void:
      tmr :> time;
      break;
    }
  }
}

[[combinable]]
void process_xscope(chanend xscope_data_in,
                    client interface wifi_network_config_if i_conf) {
  int bytesRead = 0;
  unsigned char buffer[256];

#if USE_CMD_LINE_ARGS
  char network_name[SSID_NAME_SIZE] = "";
  char network_key[WIFI_MAX_KEY_LENGTH] = "";
  parse_command_line(1, network_name);
  parse_command_line(2, network_key);

  // Join the network
  delay_seconds(3);
  i_conf.scan_for_networks();
  i_conf.join_network_by_name(network_name, network_key, strlen(network_key));
#endif

  xscope_connect_data_from_host(xscope_data_in);

  printstrln("XMOS WIFI demo:\n");

  while (1) {
    select {
      case xscope_data_from_host(xscope_data_in, buffer, bytesRead):
      if (bytesRead) {
        if (strcmp(buffer, "scan") == 0) {
          i_conf.scan_for_networks();

        } else if (strcmp(buffer, "join") == 0) {
          xscope_data_from_host(xscope_data_in, buffer, bytesRead);
          xassert(bytesRead && msg("Scan index data too short\n"));
          size_t index = strtoul(buffer, NULL, 0);
          xscope_data_from_host(xscope_data_in, buffer, bytesRead);
          xassert(bytesRead <= WIFI_MAX_KEY_LENGTH &&
                  msg("Security key data too long\n"));
          // -1 due to \n being sent
          i_conf.join_network_by_index(index, buffer, bytesRead-1);
        }
      }
      break;
    }
  }
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

void ethernet_wifi_cfg(client interface wifi_network_config_if wifi_cfg, server ethernet_cfg_if i_cfg)
{
  while (1) {
    select {
      case i_cfg.set_macaddr(size_t ifnum, uint8_t mac_address[MACADDR_NUM_BYTES]):
        uint8_t mac_address_tmp[MACADDR_NUM_BYTES];
        memcpy(mac_address_tmp, mac_address, sizeof(uint8_t)*MACADDR_NUM_BYTES);

        wifi_cfg.set_mac_address(mac_address_tmp);

        memcpy(mac_address, mac_address_tmp, sizeof(uint8_t)*MACADDR_NUM_BYTES);
        break;

      case i_cfg.get_macaddr(size_t ifnum, uint8_t mac_address[MACADDR_NUM_BYTES]):
        uint8_t mac_address_tmp[MACADDR_NUM_BYTES];
        memcpy(mac_address_tmp, mac_address, sizeof(uint8_t)*MACADDR_NUM_BYTES);

        wifi_cfg.get_mac_address(mac_address_tmp);

        memcpy(mac_address, mac_address_tmp, sizeof(uint8_t)*MACADDR_NUM_BYTES);
        break;

      case i_cfg.set_link_state(int ifnum, ethernet_link_state_t new_state, ethernet_speed_t speed):
        break;

      case i_cfg.add_macaddr_filter(size_t client_num, int is_hp, ethernet_macaddr_filter_t entry) -> ethernet_macaddr_filter_result_t result:
        result = ETHERNET_MACADDR_FILTER_TABLE_FULL;
        break;

      case i_cfg.del_macaddr_filter(size_t client_num, int is_hp, ethernet_macaddr_filter_t entry):
        break;

      case i_cfg.del_all_macaddr_filters(size_t client_num, int is_hp):
        break;

      case i_cfg.add_ethertype_filter(size_t client_num, uint16_t ethertype):
        break;

      case i_cfg.del_ethertype_filter(size_t client_num, uint16_t ethertype):
        break;

      case i_cfg.get_tile_id_and_timer_value(unsigned &tile_id, unsigned &time_on_tile):
        break;

      case i_cfg.set_egress_qav_idle_slope(size_t ifnum, unsigned slope):
        break;

      case i_cfg.set_ingress_timestamp_latency(size_t ifnum, ethernet_speed_t speed, unsigned value):
        break;

      case i_cfg.set_egress_timestamp_latency(size_t ifnum, ethernet_speed_t speed, unsigned value):
        break;

      case i_cfg.enable_strip_vlan_tag(size_t client_num):
        break;

      case i_cfg.disable_strip_vlan_tag(size_t client_num):
        break;

      case i_cfg.enable_link_status_notification(size_t client_num):
        break;

      case i_cfg.disable_link_status_notification(size_t client_num):
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
  xtcp_if i_xtcp[1];
  ethernet_cfg_if i_cfg[NUM_CFG_CLIENTS];
  ethernet_rx_if i_rx[NUM_ETH_CLIENTS];
  ethernet_tx_if i_tx[NUM_ETH_CLIENTS];
  chan c_xscope_data_in;

  par {
    xscope_host_data(c_xscope_data_in);

    on tile[1]: process_xscope(c_xscope_data_in, i_conf[CONFIG_XSCOPE]);
    on tile[1]: wifi_broadcom_wiced_builtin_spi(i_hal, 1, i_conf, NUM_CONFIG,
                                                i_data, p_wifi_spi, i_inputs[0],
                                                i_fs[0]);
    on tile[1]: input_gpio_with_events(i_inputs, 1, p_irq, null);
    on tile[1]: wifi_ethernet_mac(i_rx[0], i_tx[0], i_hal[0], i_data);
    on tile[1]: ethernet_wifi_cfg(i_conf[CONFIG_XTCP], i_cfg[CFG_TO_XTCP]);
    on tile[0]: {
      delay_seconds(3);
      xtcp_lwip(i_xtcp, 1, null, i_cfg[CFG_TO_XTCP], i_rx[ETH_TO_XTCP], i_tx[ETH_TO_XTCP], null, ETHERNET_SMI_PHY_ADDRESS, null, null, ipconfig);
    }
#if USE_SLEEP_CLOCK
    on tile[0]: sleep_clock_gen();
#endif
    on tile[0]: filesystem_tasks(i_fs);
#if USE_UDP_REFLECTOR
    on tile[0]: udp_reflect(i_xtcp[0]);
#endif
  }

  return 0;
}
