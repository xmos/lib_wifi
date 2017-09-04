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

typedef struct dhcp_state_t {
  const xtcp_ipaddr_t server_ip_address;
  const xtcp_ipaddr_t subnet_mask;
  const xtcp_ipaddr_t zero_ip_address;
  const char * movable domain_name;
  xtcp_ipaddr_t next_ip_address;
} dhcp_state_t;

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

static unsigned int dhcp_option_length(const dhcp_option_t & dhcp_option)
{
  switch (dhcp_option.type) {
    case DHCP_OPTION_PADDING:
    case DHCP_OPTION_END:
      return 1;
    default:
      return 2 + dhcp_option.length;
  }
}

static unsigned int dhcp_options_length(const dhcp_packet_t & dhcp_packet)
{
  unsigned int result = 1;
  for (
    dhcp_option_t option = dhcp_option_begin(dhcp_packet);
    !dhcp_option_is_end(option);
    option = dhcp_option_next(option)
  ) {
    result += dhcp_option_length(option);
  }

  return result;
}

static unsigned int dhcp_packet_length(const dhcp_packet_t & dhcp_packet)
{
  return DHCP_PREFIX_LENGTH + dhcp_options_length(dhcp_packet);
}

#define MIN(x,y) ((x < y) ? x : y)

static int dhcp_get_option(const dhcp_packet_t & dhcp_packet, const dhcp_option_type_t dhcp_option_type, const unsigned char payload_length, unsigned char payload[payload_length])
{
  for(unsigned char * ptr = dhcp_packet.options; ptr[0] != DHCP_OPTION_END; ptr = ptr + (2 + ptr[1])) {
    if (ptr[0] == dhcp_option_type) {
      memcpy(payload, ptr + 2, MIN(payload_length, ptr[1]));
      return 1;
    }
  }

  return 0;
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

static void dhcp_on_discover(client xtcp_if i_xtcp, xtcp_connection_t & conn, dhcp_state_t & state, const dhcp_packet_t & dhcp_packet)
{
  dhcp_packet_t result = dhcp_packet;

  err_t error = etharp_add_static_entry((void*)state.next_ip_address, (void*)dhcp_packet.client_hardware_address);

  result.op = DHCP_OP_BOOT_REPLY;
  result.secs = 0;
  memset(result.client_ip_address, 0, sizeof(xtcp_ipaddr_t));
  memcpy(result.your_ip_address, state.next_ip_address, sizeof(xtcp_ipaddr_t));
  memcpy(result.server_ip_address, state.server_ip_address, sizeof(xtcp_ipaddr_t));
  memset(result.server_host_name, 0, sizeof(char)*64);
  memset(result.boot_file_name, 0, sizeof(char)*128);
  memset(result.options, 0x00, sizeof(char)*308);
  result.options[0] = 0xFF;

  unsigned char type = DHCP_OFFER;
  unsigned int time  = 0xFFFFFFFF;
  dhcp_add_option(result, DHCP_OPTION_MESSAGE_TYPE, 1, &type);
  dhcp_add_option(result, DHCP_OPTION_SERVER_IDENTIFIER, 4, state.server_ip_address);
  dhcp_add_option(result, DHCP_OPTION_IP_ADDRESS_LEASE_TIME, 4, (void*)&time);
  dhcp_add_option(result, DHCP_OPTION_SUBNET_MASK, 4, state.subnet_mask);
  dhcp_add_option(result, DHCP_OPTION_ROUTER, 4, state.server_ip_address);
  dhcp_add_option(result, DHCP_OPTION_DNS_SERVER, 4, state.server_ip_address);
  dhcp_add_option(result, DHCP_OPTION_DOMAIN_NAME, strlen(state.domain_name), state.domain_name);

  i_xtcp.bind_remote_udp(conn, state.next_ip_address, REMOTE_PORT);
  i_xtcp.bind_local_udp(conn, LOCAL_PORT);

  unsafe {
    const int result = i_xtcp.send(conn, (char*)&result, sizeof(result));
  }

  i_xtcp.bind_remote_udp(conn, state.zero_ip_address, REMOTE_PORT);
  i_xtcp.bind_local_udp(conn, LOCAL_PORT);
}

static void dhcp_on_request(client xtcp_if i_xtcp, xtcp_connection_t & conn, dhcp_state_t & state, const dhcp_packet_t & dhcp_packet)
{
  dhcp_packet_t result = dhcp_packet;

  err_t error = etharp_add_static_entry((void*)state.next_ip_address, (void*)dhcp_packet.client_hardware_address);

  result.op = DHCP_OP_BOOT_REPLY;
  memcpy(result.your_ip_address, state.next_ip_address, sizeof(xtcp_ipaddr_t));
  memcpy(result.server_ip_address, state.server_ip_address, sizeof(xtcp_ipaddr_t));
  memset(result.server_host_name, 0, sizeof(char)*64);
  memset(result.boot_file_name, 0, sizeof(char)*128);
  memset(result.options, 0x00, sizeof(char)*308);
  result.options[0] = 0xFF;

  unsigned char type = DHCP_ACK;
  unsigned int time  = 0xFFFFFFFF;
  dhcp_add_option(result, DHCP_OPTION_MESSAGE_TYPE, 1, &type);
  dhcp_add_option(result, DHCP_OPTION_SERVER_IDENTIFIER, 4, state.server_ip_address);
  dhcp_add_option(result, DHCP_OPTION_IP_ADDRESS_LEASE_TIME, 4, (void*)&time);
  dhcp_add_option(result, DHCP_OPTION_SUBNET_MASK, 4, state.subnet_mask);
  dhcp_add_option(result, DHCP_OPTION_ROUTER, 4, state.server_ip_address);
  dhcp_add_option(result, DHCP_OPTION_DNS_SERVER, 4, state.server_ip_address);
  dhcp_add_option(result, DHCP_OPTION_DOMAIN_NAME, strlen(state.domain_name), state.domain_name);

  i_xtcp.bind_remote_udp(conn, state.next_ip_address, REMOTE_PORT);
  i_xtcp.bind_local_udp(conn, LOCAL_PORT);

  unsafe {
    const int result = i_xtcp.send(conn, (char*)&result, sizeof(result));
  }

  i_xtcp.bind_remote_udp(conn, state.zero_ip_address, REMOTE_PORT);
  i_xtcp.bind_local_udp(conn, LOCAL_PORT);

  state.next_ip_address[3]++;
}

static void dhcp_handle(client xtcp_if i_xtcp, xtcp_connection_t & conn, dhcp_state_t & state, const dhcp_packet_t & dhcp_packet)
{
  switch (dhcp_message_type(dhcp_packet)) {
    case DHCP_DISCOVER:
      dhcp_on_discover(i_xtcp, conn, state, dhcp_packet);
      break;
    case DHCP_REQUEST:
      dhcp_on_request(i_xtcp, conn, state, dhcp_packet);
      break;
  }
}

void dhcp_server(client xtcp_if i_xtcp)
{
  dhcp_state_t state = {
    {192, 168,   0,   1},
    {255, 255, 255,   0},
    {  0,   0,   0,   0},
    "vda.local",
    {192, 168,   0,   2}
  };
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
        case XTCP_RECV_DATA:
          unsafe {
            dhcp_packet_t dhcp_packet;
            const int result = i_xtcp.recv(conn, (char*)&dhcp_packet, sizeof(dhcp_packet));
            dhcp_handle(i_xtcp, conn, state, dhcp_packet);
          }
          break;
        default:
          break;
      }
      break;
    }
  }
}
