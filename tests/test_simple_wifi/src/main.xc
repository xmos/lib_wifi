// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <platform.h>
#include <xscope.h>
#include <quadflash.h>
#include <print.h>
#include <string.h>
#include <stdlib.h>

#include "wifi.h"
#include "spi.h"
#include "gpio.h"
#include "qspi_flash_storage_media.h"
#include "filesystem.h"
#include "xtcp.h"

#include "debug_print.h"
#include "xassert.h"

#define USE_WIFI_BUILTIN_SPI 1
#define USE_ASYNC_SPI 0
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

#if USE_WIFI_BUILTIN_SPI
wifi_spi_ports p_wifi_spi = {
  on tile[1]: XS1_PORT_1N,
  on tile[1]: XS1_PORT_1M,
  on tile[1]: XS1_PORT_1L,
  on tile[1]: XS1_PORT_4E,
  0, // CS on bit 0 of port 4E
  on tile[1]: XS1_CLKBLK_3,
  1, // 100/4 (2*2n)
  1000,
  0
};
#else
// These ports are used for the SPI master
out buffered port:32 p_sclk  = on tile[1]:   XS1_PORT_1N;
out          port    p_ss[1] = on tile[1]: { XS1_PORT_4E }; // Bit 0
in  buffered port:32 p_miso  = on tile[1]:   XS1_PORT_1M;
out buffered port:32 p_mosi  = on tile[1]:   XS1_PORT_1L;
#endif

// Input port used for IRQ interrupt line
in port p_irq = on tile[1]: XS1_PORT_4F;

fl_QSPIPorts qspi_flash_ports = {
  PORT_SQI_CS,
  PORT_SQI_SCLK,
  PORT_SQI_SIO,
  on tile[0]: XS1_CLKBLK_1
};

#if USE_ASYNC_SPI
clock clk0 = on tile[1]: XS1_CLKBLK_1;
clock clk1 = on tile[1]: XS1_CLKBLK_2;
#endif

/* IP Config - change this to suit your network
 * Leave with all 0 values to use DHCP/AutoIP
 */
xtcp_ipconfig_t ipconfig = {
                            { 0, 0, 0, 0 }, // ip address (e.g. 192,168,0,2)
                            { 0, 0, 0, 0 }, // netmask (e.g. 255,255,255,0)
                            { 0, 0, 0, 0 }  // gateway (e.g. 192,168,0,1)
};

void application(client interface wifi_hal_if i_hal,
                 client interface wifi_network_config_if i_conf) {
  while (1);
}

void filesystem_tasks(server interface fs_basic_if i_fs[]) {
  interface fs_storage_media_if i_media;
  fl_QuadDeviceSpec qspi_spec = FL_QUADDEVICE_ISSI_IS25LQ016B;

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
void udp_reflect(chanend c_xtcp)
{
  xtcp_connection_t conn;  // A temporary variable to hold
                           // connections associated with an event
  xtcp_connection_t responding_connection; // The connection to the remote end
                                           // we are responding to
  xtcp_connection_t broadcast_connection; // The connection out to the broadcast
                                          // address
  xtcp_ipaddr_t broadcast_addr = BROADCAST_ADDR;
  // int send_flag = TRUE;
  int send_flag = FALSE;  // This flag is set when the thread is in the
                      // middle of sending a response packet
  int broadcast_send_flag = FALSE; // This flag is set when the thread is in the
                               // middle of sending a broadcast packet
  timer tmr;
  unsigned int time;

  // The buffers for incoming data, outgoing responses and outgoing broadcast
  // messages
  char rx_buffer[RX_BUFFER_SIZE];
  char tx_buffer[RX_BUFFER_SIZE];
  char broadcast_buffer[RX_BUFFER_SIZE] = BROADCAST_MSG;

  int response_len;  // The length of the response the thread is sending
  int broadcast_len; // The length of the broadcast message the thread is
                     // sending


  // Maintain track of two connections. Initially they are not initialized
  // which can be represented by setting their ID to -1
  responding_connection.id = INIT_VAL;
  broadcast_connection.id = INIT_VAL;

  // Instruct server to listen and create new connections on the incoming port
  xtcp_listen(c_xtcp, INCOMING_PORT, XTCP_PROTOCOL_TCP);

  tmr :> time;
  while (1) {
    select {

    // Respond to an event from the tcp server
    case xtcp_event(c_xtcp, conn):
      switch (conn.event)
        {
        case XTCP_IFUP:
          // When the interface goes up, set up the broadcast connection.
          // This connection will persist while the interface is up
          // and is only used for outgoing broadcast messages
          xtcp_connect(c_xtcp,
                       BROADCAST_PORT,
                       broadcast_addr,
                       XTCP_PROTOCOL_UDP);
          debug_printf("IFUP\n");
          break;

        case XTCP_IFDOWN:
          // Tidy up and close any connections we have open
          if (responding_connection.id != INIT_VAL) {
            xtcp_close(c_xtcp, responding_connection);
            responding_connection.id = INIT_VAL;
          }
          if (broadcast_connection.id != INIT_VAL) {
            xtcp_close(c_xtcp, broadcast_connection);
            broadcast_connection.id = INIT_VAL;
          }
          debug_printf("IFDOWN\n");
          break;

        case XTCP_NEW_CONNECTION:

          // The tcp server is giving us a new connection.
          // It is either a remote host connecting on the listening port
          // or the broadcast connection the threads asked for with
          // the xtcp_connect() call
          if (XTCP_IPADDR_CMP(conn.remote_addr, broadcast_addr)) {
            // This is the broadcast connection
            debug_printf("New broadcast connection established: %d\n", conn.id);
            broadcast_connection = conn;
         }
          else {
            // This is a new connection to the listening port
            debug_printf("New connection to listening port: %d\n", conn.local_port);
            if (responding_connection.id == INIT_VAL) {
              responding_connection = conn;
            }
            else {
              debug_printf("Cannot handle new connection\n");
              xtcp_close(c_xtcp, conn);
            }
          }
          break;

        case XTCP_RECV_DATA:
          // When we get a packet in:
          //
          //  - fill the tx buffer
          //  - initiate a send on that connection
          //
          response_len = xtcp_recv_count(c_xtcp, rx_buffer, RX_BUFFER_SIZE);
          debug_printf("Got data: %d bytes\n", response_len);
          xscope_int(MP3_DECODE_START, response_len);

          for (int i=0;i<response_len;i++)
            tx_buffer[i] = rx_buffer[i];

          if (!send_flag) {
            xscope_int(MP3_DECODE_STOP, response_len);
            xtcp_init_send(c_xtcp, conn);
            send_flag = TRUE;
            debug_printf("Responding\n");
          }
          else {
            // Cannot respond here since the send buffer is being used
          }
          break;

      case XTCP_REQUEST_DATA:
      case XTCP_RESEND_DATA:
        // The tcp server wants data, this may be for the broadcast connection
        // or the reponding connection

        if (conn.id == broadcast_connection.id) {
          xtcp_send(c_xtcp, broadcast_buffer, broadcast_len);
        }
        else {
          xtcp_send(c_xtcp, tx_buffer, response_len);
        }
        break;

      case XTCP_SENT_DATA:
        xtcp_complete_send(c_xtcp);
        if (conn.id == broadcast_connection.id) {
          // When a broadcast message send is complete the connection is kept
          // open for the next one
          debug_printf("Sent Broadcast\n");
          broadcast_send_flag = FALSE;
        }
        else {
          // When a reponse is sent, the connection is closed opening up
          // for another new connection on the listening port
          debug_printf("Sent Response\n");
          send_flag = FALSE;
        }
        break;

      case XTCP_TIMED_OUT:
      case XTCP_ABORTED:
      case XTCP_CLOSED:
        debug_printf("Closed connection: %d\n", conn.id);
        xtcp_close(c_xtcp, conn);
        responding_connection.id = INIT_VAL;
        break;

      case XTCP_ALREADY_HANDLED:
          break;
      }
      break;

    // This is the periodic case, it occurs every BROADCAST_INTERVAL
    // timer ticks
    case tmr when timerafter(time + BROADCAST_INTERVAL) :> void:

      // A broadcast message can be sent if the connection is established
      // and one is not already being sent on that connection
      if (broadcast_connection.id != INIT_VAL && !broadcast_send_flag)  {
        debug_printf("Sending broadcast message\n");
        broadcast_len = strlen(broadcast_buffer);
        xtcp_init_send(c_xtcp, broadcast_connection);
        broadcast_send_flag = TRUE;
      } else {
        debug_printf("No broadcast connection\n");
      }
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

  xscope_connect_data_from_host(xscope_data_in);

  printstrln("XMOS WIFI demo:\n");

  while (1) {
    select {
      case xscope_data_from_host(xscope_data_in, buffer, bytesRead):
      if (bytesRead) {
        debug_printf("xCORE received '%s'\n", buffer);
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
  CONFIG_APP = 0,
  CONFIG_XTCP,
  CONFIG_XSCOPE,
  NUM_CONFIG
} config_interfaces;

int main(void) {
  interface wifi_hal_if i_hal[2];
  interface wifi_network_config_if i_conf[NUM_CONFIG];
  interface xtcp_pbuf_if i_data;
#if USE_ASYNC_SPI
  interface spi_master_async_if i_async_spi[1];
#else
  interface spi_master_if i_spi[1];
#endif
  interface input_gpio_if i_inputs[1];
  interface fs_basic_if i_fs[1];
  chan c_xscope_data_in;

  chan c_xtcp[1];

  par {
    xscope_host_data(c_xscope_data_in);

    on tile[1]:                process_xscope(c_xscope_data_in,
                                              i_conf[CONFIG_XSCOPE]);
#if USE_WIFI_BUILTIN_SPI
    on tile[1]:                wifi_broadcom_wiced_builtin_spi(i_hal, 2,
                                                               i_conf, NUM_CONFIG,
                                                               i_data,
                                                               p_wifi_spi,
                                                               i_inputs[0],
                                                               i_fs[0]);
#elif USE_ASYNC_SPI
    on tile[1]:                spi_master_async(i_async_spi, 1, p_sclk, p_mosi,
                                                p_miso, p_ss, 1, clk0, clk1);
    on tile[1]:                wifi_broadcom_wiced_asyc_spi(i_hal, 2, i_conf,
                                                            NUM_CONFIG, i_data,
                                                            i_async_spi[0], 0,
                                                            i_inputs[0],
                                                            i_fs[0]);
#else
    on tile[1]: [[distribute]] spi_master(i_spi, 1, p_sclk, p_mosi, p_miso,
                                          p_ss, 1, null);
    on tile[1]:                wifi_broadcom_wiced_spi(i_hal, 2, i_conf,
                                                       NUM_CONFIG, i_data,
                                                       i_spi[0], 0, i_inputs[0],
                                                       i_fs[0]);
#endif
    on tile[1]:                application(i_hal[0], i_conf[CONFIG_APP]); // TODO: remove
    on tile[1]:                input_gpio_with_events(i_inputs, 1, p_irq, null);
    on tile[1]:                xtcp_lwip_wifi(c_xtcp, 1, i_hal[1],
                                              i_conf[CONFIG_XTCP],
                                              i_data, ipconfig);
#if USE_SLEEP_CLOCK
    on tile[0]:                sleep_clock_gen();
#endif
    on tile[0]:                filesystem_tasks(i_fs);
#if USE_UDP_REFLECTOR
    on tile[0]:                udp_reflect(c_xtcp[0]);
#endif
  }

  return 0;
}
