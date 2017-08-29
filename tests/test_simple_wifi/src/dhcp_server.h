#ifndef _DHCP_SERVER_H_
#define _DHCP_SERVER_H_

#include "xtcp.h"

typedef struct dhcp_option_t {
  unsigned char type;
  unsigned char length;
  const unsigned char * unsafe payload;
} dhcp_option_t;

typedef enum dhcp_option_type_t {
  DHCP_OPTION_PADDING = 0x00,
  DHCP_OPTION_SUBNET_MASK = 0x01,
  DHCP_OPTION_ROUTER = 0x03,
  DHCP_OPTION_DNS_SERVER = 0x06,
  DHCP_OPTION_HOST_NAME = 0x0c,
  DHCP_OPTION_DOMAIN_NAME = 0x0F,
  DHCP_OPTION_IP_ADDRESS_LEASE_TIME = 0x33,
  DHCP_OPTION_MESSAGE_TYPE = 0x35,
  DHCP_OPTION_SERVER_IDENTIFIER = 0x36,
  DHCP_OPTION_PARAMETER_LIST = 0x37,
  DHCP_OPTION_MESSAGE_SIZE = 0x39,
  DHCP_OPTION_CLIENT_IDENTIFIER = 0x3d,
  DHCP_OPTION_END = 0xFF
} dhcp_option_type_t;

typedef struct dhcp_packet_t {
  unsigned char op;
  unsigned char htype;
  unsigned char hlen;
  unsigned char hops;
  unsigned int xid;
  unsigned short secs;
  unsigned short flags;
  xtcp_ipaddr_t client_ip_address;
  xtcp_ipaddr_t your_ip_address;
  xtcp_ipaddr_t server_ip_address;
  xtcp_ipaddr_t gateway_ip_address;
  unsigned char client_hardware_address[16];
  char server_host_name[64];
  char boot_file_name[128];
  unsigned int magic_cookie;
  unsigned char options[312];
} dhcp_packet_t;

typedef enum dhcp_op_t {
  DHCP_OP_BOOT_REQUEST = 1,
  DHCP_OP_BOOT_REPLY   = 2
} dhcp_op_t;

typedef enum dhcp_message_type_t {
  DHCP_UNKNOWN  = -1,
  DHCP_DISCOVER = 1,
  DHCP_OFFER,
  DHCP_REQUEST,
  DHCP_DECLINE,
  DHCP_ACK,
  DHCP_NAK,
  DHCP_RELEASE,
} dhcp_message_type_t;

void dhcp_server(client xtcp_if i_xtcp);

#endif
