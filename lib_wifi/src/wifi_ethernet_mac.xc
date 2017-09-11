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
