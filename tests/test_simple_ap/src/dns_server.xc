#include "dns_server.h"
#include "debug_print.h"
#include "xassert.h"
#include <string.h>

static unsigned short htons(unsigned short x)
{
  return (x >> 8) | (x << 8);
}

static void dns_htons(dns_packet_t & packet)
{
  packet.flags            = htons(packet.flags);
  packet.question_count   = htons(packet.question_count);
  packet.answer_count     = htons(packet.answer_count);
  packet.authority_count  = htons(packet.authority_count);
  packet.additional_count = htons(packet.additional_count);
}

static dns_question_t dns_question_end()
{
  dns_question_t result = { NULL, 0, DNS_QUESTION_TYPE_UNKNOWN, DNS_QUESTION_CLASS_UNKNOWN, 0xFFFF };
  return result;
}

static int dns_question_is_end(const dns_question_t & question)
{
  return NULL == question.name;
}

static dns_question_t dns_question_begin(const dns_packet_t & packet)
{
  dns_question_t result = dns_question_end();

  if (packet.question_count > 0) {
    const unsigned char * ptr = packet.payload;
    const char * name_ptr = (const char*)ptr;
    const unsigned int length = strlen(ptr);

    const unsigned char * type_ptr  = ptr + (length + 1);
    const unsigned char * class_ptr = ptr + (length + sizeof(unsigned short) + 1);
    unsafe { result.name = name_ptr; }
    memcpy(&result.type, type_ptr, sizeof(unsigned short));
    memcpy(&result.class, class_ptr, sizeof(unsigned short));
    result.index = 0;
    result.name_length = length;
  }

  return result;
}

static dns_question_t dns_question_next(const dns_packet_t & packet, const dns_question_t & current)
{
  dns_question_t result = dns_question_end();

  if (current.index + 1 < packet.question_count) {
    const unsigned char * ptr = NULL;
    unsafe {
      ptr = (const unsigned char *)current.name;
    }
    ptr = ptr + (current.name_length + sizeof(unsigned short) + sizeof(unsigned short));

    const char * name_ptr = (const char*)ptr;
    const unsigned int length = strlen(name_ptr);

    const unsigned char * type_ptr  = ptr + (length + 1);
    const unsigned char * class_ptr = ptr + (length + sizeof(unsigned short) + 1);
    unsafe { result.name = name_ptr; }
    memcpy(&result.type, type_ptr, sizeof(unsigned short));
    memcpy(&result.class, class_ptr, sizeof(unsigned short));
    result.index = current.index + 1;
    result.name_length = length;
  }

  return result;
}

static dns_record_t dns_record_end()
{
  dns_record_t result = {NULL, 0, DNS_QUESTION_TYPE_UNKNOWN, DNS_QUESTION_CLASS_UNKNOWN, 0, 0, NULL};

  return result;
}

static int dns_record_is_end(const dns_record_t & record)
{
  return NULL == record.name;
}

static unsigned int dns_question_length(const dns_question_t & question)
{
  return sizeof(char) + question.name_length + (sizeof(unsigned short) * 2);
}

static unsigned int dns_questions_length(const dns_packet_t & packet)
{
  unsigned int result = 0;

  for (dns_question_t q = dns_question_begin(packet); !dns_question_is_end(q); q = dns_question_next(packet, q)) {
    result += dns_question_length(q);
  }

  return result;
}

static dns_record_t dns_answer_begin(const dns_packet_t & packet)
{
  dns_record_t result = dns_record_end();

  if (packet.answer_count > 0) {
    const unsigned int questions_length         = dns_questions_length(packet);
    const unsigned char * const name_ptr        = packet.payload + questions_length;
    const unsigned int name_length              = strlen(name_ptr);
    const unsigned char * const type_ptr        = name_ptr + name_length + 1;
    const unsigned char * const class_ptr       = type_ptr + sizeof(short);
    const unsigned char * const ttl_ptr         = class_ptr + sizeof(short);
    const unsigned char * const payload_len_ptr = ttl_ptr + sizeof(int);
    const unsigned char * const payload_ptr     = payload_len_ptr + sizeof(short);

    unsafe {result.name = name_ptr;}
    result.name_length = name_length;
    memcpy(&result.type, type_ptr, sizeof(short));
    memcpy(&result.class, class_ptr, sizeof(short));
    memcpy(&result.ttl, ttl_ptr, sizeof(int));
    memcpy(&result.payload_length, payload_len_ptr, sizeof(short));
    unsafe {result.payload = payload_ptr;}
    result.index = 0;
  }

  return result;
}

static dns_record_t dns_answer_next(const dns_packet_t & packet, const dns_record_t & current)
{
  dns_record_t next = dns_record_end();

  if (current.index + 1 < packet.answer_count) {
    const unsigned char * ptr = NULL;
    unsafe {ptr = (void*)current.payload + current.payload_length;}

    const unsigned char * const name_ptr        = ptr;
    const unsigned int name_length              = strlen(name_ptr);
    const unsigned char * const type_ptr        = name_ptr + name_length + 1;
    const unsigned char * const class_ptr       = type_ptr + sizeof(short);
    const unsigned char * const ttl_ptr         = class_ptr + sizeof(short);
    const unsigned char * const payload_len_ptr = ttl_ptr + sizeof(int);
    const unsigned char * const payload_ptr     = payload_len_ptr + sizeof(short);

    unsafe {next.name = name_ptr;}
    next.name_length = name_length;
    memcpy(&next.type, type_ptr, sizeof(short));
    memcpy(&next.class, class_ptr, sizeof(short));
    memcpy(&next.ttl, ttl_ptr, sizeof(int));
    memcpy(&next.payload_length, payload_len_ptr, sizeof(short));
    unsafe {next.payload = payload_ptr;}
    next.index = 0;
  }

  return next;
}

static unsigned int dns_record_length(const dns_record_t & record)
{
  return 11 + record.name_length + record.payload_length;
}

static unsigned int dns_answers_length(const dns_packet_t & packet)
{
  unsigned int result = 0;

  for (dns_record_t r = dns_answer_begin(packet); !dns_record_is_end(r); r = dns_answer_next(packet, r)) {
    result += dns_record_length(r);
  }

  return result;
}

static unsigned int dns_packet_length(const dns_packet_t & packet)
{
  return 12 + dns_questions_length(packet) + dns_answers_length(packet);
}

static void dns_add_question(const dns_question_t & question, dns_packet_t & packet)
{
  const unsigned int payload_length   = dns_packet_length(packet) - 12;
  unsigned char * const payload_begin = packet.payload;
  unsigned char * const payload_end   = packet.payload + payload_length;

  const unsigned int question_length       = dns_question_length(question);
  unsigned char * const question_name_ptr  = packet.payload;
  unsigned char * const question_type_ptr  = question_name_ptr + question.name_length + sizeof(char);
  unsigned char * const question_class_ptr = question_type_ptr + sizeof(unsigned short);
  unsigned char * const question_end       = question_class_ptr + sizeof(unsigned short);

  xassert((payload_end + question_length) < (packet.payload + DNS_MAX_PAYLOAD_SIZE));

  memmove(question_end, payload_begin, payload_length);
  memcpy(question_name_ptr, question.name, question.name_length + sizeof(char));
  memcpy(question_type_ptr, &question.type, sizeof(unsigned short));
  memcpy(question_class_ptr, &question.class, sizeof(unsigned short));

  packet.question_count++;
}

static void dns_add_answer(const dns_record_t & record, dns_packet_t & packet)
{
  const unsigned int payload_length   = dns_packet_length(packet) - 12;
  unsigned char * const payload_begin = packet.payload;
  unsigned char * const payload_end   = packet.payload + payload_length;
  unsigned char * const packet_end    = payload_begin + DNS_MAX_PAYLOAD_SIZE;

  const unsigned int questions_length   = dns_questions_length(packet);
  unsigned char * const questions_begin = payload_begin;
  unsigned char * const questions_end   = questions_begin + questions_length;

  const unsigned int record_length         = dns_record_length(record);
  unsigned char * const record_begin       = questions_end;
  unsigned char * const record_name_ptr    = record_begin;
  unsigned char * const record_type_ptr    = record_name_ptr + 1 + record.name_length;
  unsigned char * const record_class_ptr   = record_type_ptr + sizeof(unsigned short);
  unsigned char * const record_ttl_ptr     = record_class_ptr + sizeof(unsigned short);
  unsigned char * const record_len_ptr     = record_ttl_ptr + sizeof(unsigned int);
  unsigned char * const record_payload_ptr = record_len_ptr + sizeof(unsigned short);
  unsigned char * const record_end         = record_begin + record_length;

  xassert((record_end + (payload_end - questions_end)) < packet_end);

  memmove(record_end, questions_end, payload_end - questions_end);
  memcpy(record_name_ptr, record.name, record.name_length + 1);
  memcpy(record_type_ptr, &record.type, sizeof(unsigned short));
  memcpy(record_class_ptr, &record.class, sizeof(unsigned short));
  memcpy(record_ttl_ptr, &record.ttl, sizeof(unsigned int));
  memcpy(record_len_ptr, &record.payload_length, sizeof(unsigned short));
  unsafe{ memcpy(record_payload_ptr, record.payload, record.payload_length); }

  packet.answer_count++;
}

static void dns_handle_question(const dns_packet_t & packet_in, const dns_question_t & current, dns_packet_t & packet_out)
{
  const char name[] = "\3vda\5setup";
  xtcp_ipaddr_t address = {192, 168,   0,   1};
  dns_record_t record;
  unsafe {record.name = name;}
  record.name_length = strlen(name);
  record.type = 0x0100;
  record.class = 0x0100;
  record.ttl = 0xFFFFFFFF;
  record.payload_length = 4;
  unsafe {record.payload = (void*)&address;}

  if (current.name_length == 10 && memcmp(current.name, name, 10) == 0) {
    packet_out.flags = 0x8000;

    dns_add_answer(record, packet_out);
  } else {
    packet_out.flags = 0x8385;
  }
}

static void dns_handle(client xtcp_if i_xtcp, xtcp_connection_t & conn, dns_packet_t & packet)
{
  dns_htons(packet);
  dns_packet_t packet_out = {packet.id, 0, 0, 0, 0, 0};

  for (dns_question_t q = dns_question_begin(packet); !dns_question_is_end(q); q = dns_question_next(packet, q)) {
    dns_add_question(q, packet_out);
    dns_handle_question(packet, q, packet_out);
  }

  const unsigned int packet_out_length = dns_packet_length(packet_out);
  debug_printf("Sending response of length %d\n", packet_out_length);
  dns_htons(packet_out);
  const int result = i_xtcp.send(conn, (void*)&packet_out, packet_out_length);
  debug_printf("Outgoing data of length %d\n", result);
}

void dns_server(client xtcp_if i_xtcp)
{
  xtcp_connection_t conn = i_xtcp.socket(XTCP_PROTOCOL_UDP);
  i_xtcp.listen(conn, 53, XTCP_PROTOCOL_UDP);

  while(1) {
    select {
      case i_xtcp.event_ready():
        xtcp_connection_t conn_tmp;

        switch(i_xtcp.get_event(conn_tmp)) {
          case XTCP_RECV_DATA:
            unsafe {
              dns_packet_t packet;
              const int result = i_xtcp.recv(conn_tmp, (void*)&packet, sizeof(packet));
              if (result > 0) {
                debug_printf("Incoming data of length %d\n", result);
                dns_handle(i_xtcp, conn_tmp, packet);
                i_xtcp.close(conn_tmp);
              }
            }
            break;
        }
        break;
    }
  }
}
