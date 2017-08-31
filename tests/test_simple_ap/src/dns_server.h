#ifndef _DNS_SERVER_H_
#define _DNS_SERVER_H_

#include "xtcp.h"

#define DNS_MAX_PAYLOAD_SIZE (500)

typedef struct dns_packet_t {
  const unsigned short id;
  unsigned short flags;
  unsigned short question_count;
  unsigned short answer_count;
  unsigned short authority_count;
  unsigned short additional_count;
  unsigned char payload[DNS_MAX_PAYLOAD_SIZE];
} dns_packet_t;

typedef enum dns_question_type_t {
  DNS_QUESTION_TYPE_UNKNOWN,
  DNS_QUESTION_TYPE_A = 0x0001
} dns_question_type_t;

typedef enum dns_question_class_t {
  DNS_QUESTION_CLASS_UNKNOWN,
  DNS_QUESTION_CLASS_IN = 0x0001
} dns_question_class_t;

typedef struct dns_question_t {
  const char * unsafe name;
  unsigned int name_length;
  dns_question_type_t type;
  dns_question_class_t class;
  unsigned short index;
} dns_question_t;

typedef struct dns_record_t {
  const char * unsafe name;
  unsigned int name_length;
  dns_question_type_t type;
  dns_question_class_t class;
  unsigned int ttl;
  unsigned short payload_length;
  unsigned char * unsafe payload;
  unsigned short index;
} dns_record_t;

void dns_server(client xtcp_if i_xtcp);

#endif
