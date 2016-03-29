#include <stddef.h>
#include "wifi.h"
#include "xtcp.h"
#include "xtcp_server.h"
#include "xtcp_server_impl.h"
#include "uip_xtcp.h"
#include "lwip_xtcp.h"
#include "lwip/autoip.h"
#include "lwip/init.h"
#include "lwip/tcp.h"
#include "lwip/tcp_impl.h"
#include "lwip/igmp.h"
#include "lwip/dhcp.h"
#include "xassert.h"

// Variable for storing the data interface  used by the xcore_netif.xc for
// sending packets
extern client interface xtcp_pbuf_if * unsafe xtcp_i_pbuf_data;

// TODO: See if xtcp_lwip_wifi can be merged with xtcp_lwip
void xtcp_lwip_wifi(chanend xtcp[n], size_t n,
                    client interface wifi_hal_if i_wifi_hal,
                    client interface wifi_network_config_if i_wifi_config,
                    client interface xtcp_pbuf_if i_wifi_data,
                    xtcp_ipconfig_t &ipconfig)
{
  timer timers[NUM_TIMEOUTS];
  unsigned timeout[NUM_TIMEOUTS];
  unsigned period[NUM_TIMEOUTS];

  char mac_address[6];
  struct netif my_netif;
  struct netif *unsafe netif;

  unsafe {
     xtcp_i_pbuf_data = (client xtcp_pbuf_if * unsafe) &i_wifi_data;
  }

  xtcpd_init(xtcp, n);

  // Initialise lwip to enable the use of pbufs in lib_wifi
  lwip_init();

  // Signal to lib_wifi that it can now start the driver and boot the radio
  delay_seconds(1);
  debug_printf("call init_radio()\n");
  i_wifi_hal.init_radio();
  debug_printf("init_radio() done\n");

  // Get the MAC address from the WiFi radio module
  if (i_wifi_config.get_mac_address(mac_address) != WIFI_SUCCESS) {
    fail("Error while getting MAC address of WiFi radio\n");
  }

  ip4_addr_t ipaddr, netmask, gateway;
  memcpy(&ipaddr, ipconfig.ipaddr, sizeof(xtcp_ipaddr_t));
  memcpy(&netmask, ipconfig.netmask, sizeof(xtcp_ipaddr_t));
  memcpy(&gateway, ipconfig.gateway, sizeof(xtcp_ipaddr_t));

  unsafe {
    netif = &my_netif;
    netif = netif_add(netif, &ipaddr, &netmask, &gateway, NULL);
    netif_set_default(netif);
  }

  xtcp_lwip_low_level_init(my_netif, mac_address); // Needs to be called after netif_add which zeroes everything

  if (ipconfig.ipaddr[0] == 0) {
    if (dhcp_start(netif) != ERR_OK) fail("DHCP error");
  }
  netif_set_up(netif);

  int time_now;
  timers[0] :> time_now;
  xtcp_lwip_init_timers(period, timeout, time_now);

  while (1) {
    unsafe {
    select {
    case i_wifi_data.packet_ready():
      struct pbuf *unsafe p = i_wifi_data.receive_packet();
      ethernet_input(p, netif); // Process the packet
      break;

    case (int i=0;i<n;i++) xtcpd_service_client(xtcp[i], i):
      break;

    case(size_t i = 0; i < NUM_TIMEOUTS; i++)
      timers[i] when timerafter(timeout[i]) :> unsigned current:

      switch (i) {
      case ARP_TIMEOUT: {
        etharp_tmr();
        // Check for the link state
        static int linkstate=0;
        ethernet_link_state_t status = i_wifi_config.get_link_state();
        if (!status && linkstate) {
          netif_set_link_down(netif);
          lwip_xtcp_down();
        }
        if (status && !linkstate) {
          netif_set_link_up(netif);
        }
        linkstate = status;

        if (!get_uip_xtcp_ifstate() && dhcp_supplied_address(netif)) {
          uint32_t ip = ip4_addr_get_u32(&netif->ip_addr);
          debug_printf("DHCP: Got %d.%d.%d.%d\n", ip4_addr1(&ip),
                                                  ip4_addr2(&ip),
                                                  ip4_addr3(&ip),
                                                  ip4_addr4(&ip));
          lwip_xtcp_up();
        }
        break;
      }
      case AUTOIP_TIMEOUT: autoip_tmr(); break;
      case TCP_TIMEOUT: tcp_tmr(); break;
      case IGMP_TIMEOUT: igmp_tmr(); break;
      case DHCP_COARSE_TIMEOUT: dhcp_coarse_tmr(); break;
      case DHCP_FINE_TIMEOUT: dhcp_fine_tmr(); break;
      default: fail("Bad timer\n"); break;
      }

      timeout[i] = current + period[i];
      uip_xtcp_checkstate();

      break;
    default:
      xtcpd_check_connection_poll();
      break;
    }
    }
  }
}
