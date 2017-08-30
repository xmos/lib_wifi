#include "dhcp_server.h"

#include <string.h>
#include "netif/etharp.h"
#include "debug_print.h"
#include "xassert.h"

#define REMOTE_PORT (68)
#define LOCAL_PORT (67)
#define BROADCAST_ADDR {255, 255, 255, 255}
#define ZERO_ADDR {0, 0, 0, 0}
#define DHCP_PREFIX_LENGTH (240)


static dhcp_option_t dhcp_option_end()
{
  dhcp_option_t result = { DHCP_OPTION_END, 0, NULL };

  return result;
}

static int dhcp_option_is_end(const dhcp_option_t & dhcp_option)
{
  return dhcp_option.type == DHCP_OPTION_END;
}

static dhcp_option_t dhcp_option_begin(const dhcp_packet_t & dhcp_packet)
{
  dhcp_option_t result = dhcp_option_end();

  result.type = *dhcp_packet.options;
  if (!dhcp_option_is_end(result)) {
    result.length = *(dhcp_packet.options + 1);
    unsafe {
      result.payload = (dhcp_packet.options + 2);
    }
  }

  return result;
}

static dhcp_option_t dhcp_option_next(const dhcp_option_t & dhcp_option)
{
  dhcp_option_t result = dhcp_option_end();

  if(!dhcp_option_is_end(dhcp_option)) {
    unsafe {
      result.type = *(dhcp_option.payload + dhcp_option.length);
      result.length = *(dhcp_option.payload + dhcp_option.length + 1);
      result.payload = dhcp_option.payload + dhcp_option.length + 2;
    }
  }

  return result;
}

static dhcp_message_type_t dhcp_message_type(const dhcp_packet_t & dhcp_packet)
{
  dhcp_message_type_t result = DHCP_UNKNOWN;

  for (
    dhcp_option_t option = dhcp_option_begin(dhcp_packet);
    !dhcp_option_is_end(option);
    option = dhcp_option_next(option)
  ) {
    if (option.type == DHCP_OPTION_MESSAGE_TYPE) {
      unsafe {
        result = *option.payload;
      }
    }
  }

  return result;
}

static unsigned int dhcp_options_length(const dhcp_packet_t & dhcp_packet)
{
  unsigned int result = 1;
  for (
    dhcp_option_t option = dhcp_option_begin(dhcp_packet);
    !dhcp_option_is_end(option);
    option = dhcp_option_next(option)
  ) {
    result += option.length + 2;
  }

  return result;
}

static unsigned int dhcp_packet_length(const dhcp_packet_t & dhcp_packet)
{
  return DHCP_PREFIX_LENGTH + dhcp_options_length(dhcp_packet);
}

static dhcp_option_t dhcp_find_option(const dhcp_packet_t & dhcp_packet, const dhcp_option_type_t dhcp_option_type)
{
  dhcp_option_t result = dhcp_option_end();

  for (
    dhcp_option_t option = dhcp_option_begin(dhcp_packet);
    !dhcp_option_is_end(option);
    option = dhcp_option_next(option)
  ) {
    if (option.type == dhcp_option_type) {
      result = option;
    }
  }

  return result;
}

static void dhcp_add_option(dhcp_packet_t & dhcp_packet, const dhcp_option_type_t dhcp_option_type, const unsigned char payload_length, const unsigned char payload[payload_length])
{
  unsigned char * ptr = dhcp_packet.options;
  while (ptr[0] != DHCP_OPTION_END) {
    ptr = ptr + (2 + ptr[1]);
  }

  ptr[0] = dhcp_option_type;
  ptr[1] = payload_length;
  memcpy(ptr + 2, payload, payload_length);

  ptr[payload_length + 2] = 0xFF;
}

static void dhcp_on_discover(client xtcp_if i_xtcp, xtcp_connection_t & conn, const dhcp_packet_t & dhcp_packet, unsigned int length)
{
  dhcp_packet_t result = dhcp_packet;
  const xtcp_ipaddr_t broadcast_addr    = BROADCAST_ADDR;
  const xtcp_ipaddr_t zero_addr         = ZERO_ADDR;
  const xtcp_ipaddr_t your_ip_address   = {192, 168,   2, 2};
  const xtcp_ipaddr_t server_ip_address = {192, 168,   2, 1};
  const xtcp_ipaddr_t net_mask          = {255, 255, 255, 0};
  const char * domain_name = "vda.local";


  err_t error = etharp_add_static_entry((void*)your_ip_address, (void*)dhcp_packet.client_hardware_address);

  result.op   = DHCP_OP_BOOT_REPLY;
  memcpy(result.your_ip_address, your_ip_address, sizeof(xtcp_ipaddr_t));
  memcpy(result.server_ip_address, server_ip_address, sizeof(xtcp_ipaddr_t));
  memset(result.server_host_name, 0, sizeof(char)*64);
  memset(result.boot_file_name, 0, sizeof(char)*128);
  memset(result.options, 0xFF, sizeof(char)*312);

  unsigned char type = DHCP_OFFER;
  unsigned int time = 0xFFFF;
  dhcp_add_option(result, DHCP_OPTION_MESSAGE_TYPE, 1, &type);
  dhcp_add_option(result, DHCP_OPTION_SUBNET_MASK, 4, net_mask);
  dhcp_add_option(result, DHCP_OPTION_SERVER_IDENTIFIER, 4, server_ip_address);
  dhcp_add_option(result, DHCP_OPTION_IP_ADDRESS_LEASE_TIME, 4, (void*)&time);
  dhcp_add_option(result, DHCP_OPTION_ROUTER, 4, server_ip_address);
  dhcp_add_option(result, DHCP_OPTION_DNS_SERVER, 4, server_ip_address);
  dhcp_add_option(result, DHCP_OPTION_DOMAIN_NAME, strlen(domain_name), domain_name);

  i_xtcp.bind_remote_udp(conn, your_ip_address, LOCAL_PORT);
  i_xtcp.bind_local_udp(conn, REMOTE_PORT);

  unsafe {
    const int result = i_xtcp.send(conn, (char*)&result, length);
    debug_printf("Outgoing data of length %d\n", result);
  }

  i_xtcp.bind_remote_udp(conn, zero_addr, REMOTE_PORT);
  i_xtcp.bind_local_udp(conn, LOCAL_PORT);
}

static void dhcp_on_request(client xtcp_if i_xtcp, xtcp_connection_t & conn, const dhcp_packet_t & dhcp_packet)
{
  static unsigned char next_address = 2;
  dhcp_packet_t result = dhcp_packet;
  const xtcp_ipaddr_t broadcast_addr    = BROADCAST_ADDR;
  const xtcp_ipaddr_t zero_addr         = ZERO_ADDR;
  const xtcp_ipaddr_t your_ip_address   = {192, 168,   2, next_address};
  const xtcp_ipaddr_t server_ip_address = {192, 168,   2, 1};
  const xtcp_ipaddr_t net_mask          = {255, 255, 255, 0};
  next_address++;

  result.op   = DHCP_OP_BOOT_REPLY;
  /*result.secs = 0;*/
  memcpy(result.your_ip_address, your_ip_address, sizeof(xtcp_ipaddr_t));
  memcpy(result.server_ip_address, server_ip_address, sizeof(xtcp_ipaddr_t));
  memset(result.server_host_name, 0, sizeof(char)*64);
  memset(result.boot_file_name, 0, sizeof(char)*128);
  memset(result.options, 0xFF, sizeof(char)*312);

  unsigned char type = DHCP_ACK;
  dhcp_add_option(result, DHCP_OPTION_MESSAGE_TYPE, 1, &type);
  dhcp_add_option(result, DHCP_OPTION_SUBNET_MASK, 4, net_mask);
  dhcp_add_option(result, DHCP_OPTION_SERVER_IDENTIFIER, 4, server_ip_address);

  i_xtcp.bind_remote_udp(conn, broadcast_addr, LOCAL_PORT);
  i_xtcp.bind_local_udp(conn, REMOTE_PORT);

  unsafe {
    const int result = i_xtcp.send(conn, (char*)&result, dhcp_packet_length(result));
    debug_printf("Outgoing data of length %d\n", result);
  }

  i_xtcp.bind_remote_udp(conn, zero_addr, REMOTE_PORT);
  i_xtcp.bind_local_udp(conn, LOCAL_PORT);
}

void dhcp_server(client xtcp_if i_xtcp)
{
  const xtcp_ipaddr_t broadcast_addr = BROADCAST_ADDR;
  const xtcp_ipaddr_t zero_addr = ZERO_ADDR;
  const xtcp_ipaddr_t server_ip_address = {192, 168, 2, 1};
  xtcp_connection_t conn = i_xtcp.socket(XTCP_PROTOCOL_UDP);
  i_xtcp.connect(conn, REMOTE_PORT, zero_addr);
  i_xtcp.bind_remote_udp(conn, zero_addr, REMOTE_PORT);
  i_xtcp.bind_local_udp(conn, LOCAL_PORT);

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
          dhcp_packet_t dhcp_packet;
          int result = 0;
          unsafe {
            result = i_xtcp.recv(conn, (char*)&dhcp_packet, sizeof(dhcp_packet));
            debug_printf("Incoming data of length %d\n", result);
          }

          switch (dhcp_message_type(dhcp_packet)) {
            case DHCP_DISCOVER:
              debug_printf("DHCP_DISCOVER\n");
              dhcp_on_discover(i_xtcp, conn, dhcp_packet, result);
              break;
            case DHCP_REQUEST:
              debug_printf("DHCP_REQUEST\n");
              dhcp_on_request(i_xtcp, conn, dhcp_packet);
              break;
            default:
              debug_printf("DHCP_UNKNOWN\n");
              break;
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
    }
  }
}
