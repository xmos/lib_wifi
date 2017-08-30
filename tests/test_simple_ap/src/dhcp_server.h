#ifndef _DHCP_SERVER_H_
#define _DHCP_SERVER_H_

#include "xtcp.h"

typedef struct dhcp_option_t {
  unsigned char type;
  unsigned char length;
  const unsigned char * unsafe payload;
} dhcp_option_t;

/** BOOTP Vendor extensions specific to DHCP as specified in RFC 2132*/
typedef enum dhcp_option_type_t {
  DHCP_OPTION_PADDING = 0x00,
  DHCP_OPTION_SUBNET_MASK = 0x01,
  DHCP_OPTION_TIME_OFFSET = 0x02,
  DHCP_OPTION_ROUTER = 0x03,
  DHCP_OPTION_TIME_SERVER = 0x04,
  DHCP_OPTION_NAME_SERVER = 0x05,
  DHCP_OPTION_DNS_SERVER = 0x06,
  DHCP_OPTION_LOG_SERVER = 0x07,
  DHCP_OPTION_COOKIE_SERVER = 0x08,
  DHCP_OPTION_LPR_SERVER = 0x09,
  DHCP_OPTION_IMPRESS_SERVER = 0x0A,
  DHCP_OPTION_RESOURCE_LOCATION_SERVER = 0x0B,
  DHCP_OPTION_HOST_NAME = 0x0C,
  DHCP_OPTION_BOOT_FILE_SIZE = 0x0D,
  DHCP_OPTION_MERIT_DUMP_FILE = 0x0E,
  DHCP_OPTION_DOMAIN_NAME = 0x0F,
  DHCP_OPTION_SWAP_SERVER = 0x10,
  DHCP_OPTION_ROOT_PATH = 0x11,
  DHCP_OPTION_EXTENSIONS_PATH = 0x12,
  DHCP_OPTION_IP_FORWARDING = 0x13,
  DHCP_OPTION_LOCAL_SOURCE_ROUTING = 0x14,
  DHCP_OPTION_POLICY_FILTER = 0x15,
  DHCP_OPTION_MAXIMUM_DATAGRAM_REASSEMBLY_SIZE = 0x16,
  DHCP_OPTION_DEFAULT_IP_TTL = 0x17,
  DHCP_OPTION_INTERFACE_MTU = 0x1A,
  DHCP_OPTION_ALL_SUBNETS_LOCAL = 0x1B,
  DHCP_OPTION_BROADCAST_ADDRESS = 0x1C,
  DHCP_OPTION_PERFORM_MASK_DISCOVERY = 0x1D,
  DHCP_OPTION_MASK_SUPPLIER = 0x1E,
  DHCP_OPTION_PERFORM_ROUTER_DISCOVERY = 0x1F,
  DHCP_OPTION_ROUTER_SOLICITATION_ADDRESS = 0x20,
  DHCP_OPTION_STATIC_ROUTE = 0x21,
  DHCP_OPTION_REQUESTED_IP_ADDRESS = 0x32,
  DHCP_OPTION_IP_ADDRESS_LEASE_TIME = 0x33,
  DHCP_OPTION_OPTION_OVERLOAD = 0x34,
  DHCP_OPTION_MESSAGE_TYPE = 0x35,
  DHCP_OPTION_SERVER_IDENTIFIER = 0x36,
  DHCP_OPTION_PARAMETER_LIST = 0x37,
  DHCP_OPTION_MESSAGE = 0x38,
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
  unsigned char options[308];
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
  DHCP_NACK,
  DHCP_RELEASE,
} dhcp_message_type_t;

typedef struct dhcp_config_t {
  xtcp_ipaddr_t server_ip_address;
  xtcp_ipaddr_t start_ip_address;
  xtcp_ipaddr_t end_ip_address;
  xtcp_ipaddr_t subnet_mask;
  xtcp_ipaddr_t router;
  xtcp_ipaddr_t dns_server;
} dhcp_config_t;

void dhcp_server(client xtcp_if i_xtcp);

#endif
