#include "wifi.h"
#include "debug_print.h"
#include "lwip/pbuf.h"

extern void lwip_init(void);

[[combinable]]
void wifi_ethernet_mac(server ethernet_rx_if i_rx,
                       server ethernet_tx_if i_tx,
                       client interface wifi_hal_if i_hal,
                       client interface xtcp_pbuf_if i_data)
{
  lwip_init();
  i_hal.init_radio();

  while(1) {
    select {
      case i_tx._get_outgoing_timestamp() -> unsigned result:
        result = 0;
        break;

      case i_tx._init_send_packet(size_t n, size_t ifnum):
        break;

      case i_tx._complete_send_packet(char packet[n], unsigned n, int request_timestamp, size_t ifnum):
        struct pbuf * unsafe buffer = pbuf_alloc(PBUF_RAW_TX, n, PBUF_POOL);

        if (NULL != buffer) {
          unsafe {
            memcpy(buffer->payload, packet, n);
          }

          i_data.send_packet(buffer);
          pbuf_free(buffer);
        }
        break;

      case i_rx.get_index() -> size_t result:
        result = 0;
        break;

      case i_rx.get_packet(ethernet_packet_info_t &desc, char packet[n], unsigned n):
        desc.type = ETH_DATA;
        struct pbuf * unsafe const data = i_data.receive_packet();

        unsafe {
          desc.len = MIN(n, data->len);
          memcpy(packet, data->payload, desc.len);
        }

        pbuf_free(data);
        break;

      case i_data.packet_ready():
        i_rx.packet_ready();
        break;
    }
  }
}

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
