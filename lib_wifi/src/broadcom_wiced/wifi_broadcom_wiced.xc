// Copyright (c) 2015-2017, XMOS Ltd, All rights reserved
#include <stddef.h>
#include <stdint.h>

#include "wifi_broadcom_wiced.h"
#include "wifi.h"
#include "wifi_spi.h"
#include "gpio.h"
#include "xc2compat.h"
#include "xc_broadcom_wiced_includes.h"
#include "lwip/pbuf.h"

#ifdef __xtcp_conf_h_exists__
#include "xtcp_conf.h"
#else
#error "Apps built to use lib_wifi must have an xtcp_conf.h which includes wifi_conf_derived.h"
#endif
#if (PBUF_LINK_ENCAPSULATION_HLEN != (WICED_PHYSICAL_HEADER)) || (PBUF_LINK_ENCAPSULATION_HLEN == 0)
#error "PBUF_LINK_ENCAPSULATION_HLEN != (WICED_PHYSICAL_HEADER)"
#error "wifi_conf_derived.h doesn't seem to be included in xtcp_conf.h"
#endif

#undef DEBUG_UNIT
#define DEBUG_UNIT WIFI_DEBUG
#include "debug_print.h"
#include "xassert.h"

typedef enum {
  WIFI_SYNCHRONOUS_SPI,
  WIFI_ASYNCHRONOUS_SPI,
  WIFI_BUILTIN_SPI
} wifi_spi_type_t;

static wifi_spi_ports * unsafe p_wifi_bcm_wiced_spi;

signals_t signals;
unsafe streaming chanend xcore_wwd_pbuf_external;
unsafe client interface fs_basic_if i_fs_global;

// Function prototype for xcore wrapper function found in xcore_wrappers.c
size_t xcore_wifi_scan_networks();
unsigned xcore_wifi_join_network_at_index(size_t index, uint8_t security_key[],
                                          size_t key_length);
unsigned xcore_wifi_leave_network();
int xcore_wifi_get_network_index(const char * unsafe name);
wwd_result_t xcore_wifi_get_radio_mac_address(wiced_mac_t * unsafe mac_address);
unsigned xcore_wifi_set_radio_mac_address(wiced_mac_t mac_address);
unsigned xcore_wifi_ready_to_transceive();
unsigned xcore_wifi_start_ap(char * unsafe ssid);
unsigned xcore_wifi_stop_ap(void);

unsafe void xcore_wiced_drive_power_line (uint32_t line_state) {
  wifi_spi_drive_cs_port_now(*p_wifi_bcm_wiced_spi, 2, line_state);
}

unsafe void xcore_wiced_drive_reset_line(uint32_t line_state) {
  wifi_spi_drive_cs_port_now(*p_wifi_bcm_wiced_spi, 1, line_state);
}

unsafe void xcore_wiced_spi_transfer(wwd_bus_transfer_direction_t direction,
                                     uint8_t * unsafe buffer,
                                     uint16_t buffer_length) {
  wifi_spi_init(*p_wifi_bcm_wiced_spi);
  if (BUS_READ == direction) {
    // Reading from the bus TO buffer
    wifi_spi_transfer(buffer_length, (char *)buffer,
                      *p_wifi_bcm_wiced_spi, WIFI_SPI_READ);
  } else { // Must be BUS_WRITE
    wifi_spi_transfer(buffer_length, (char *)buffer,
                      *p_wifi_bcm_wiced_spi, WIFI_SPI_WRITE);
  }
}

void xcore_wiced_send_pbuf_to_internal(pbuf_p p) {
  unsafe {
    xcore_wwd_pbuf_external <: p;
  }
}

unsigned xcore_get_ticks() {
  timer t;
  unsigned time;
  t :> time;
  return time;
}

/*
 * A structure for storing pbuf pointers. It is empty when head == tail.
 */
#define NUM_BUFFERS 10
typedef struct {
  pbuf_p buffers[NUM_BUFFERS];
  unsigned head;
  unsigned tail;
} buffers_t;

static void buffers_init(buffers_t &buffers) {
  buffers.head = 0;
  buffers.tail = 0;
}

static unsafe pbuf_p buffers_take(buffers_t &buffers) {
  xassert(buffers.head != buffers.tail);
  unsigned read_index = buffers.head;
  buffers.head += 1;
  if (buffers.head == NUM_BUFFERS) {
    buffers.head = 0;
  }
  return buffers.buffers[read_index];
}

static unsafe void buffers_put(buffers_t &buffers, pbuf_p p) {
  buffers.buffers[buffers.tail] = p;
  buffers.tail += 1;
  if (buffers.tail == NUM_BUFFERS) {
    buffers.tail = 0;
  }
  xassert(buffers.head != buffers.tail);
}

static int buffers_is_empty(buffers_t &buffers){
  return (buffers.head == buffers.tail);
}

#define MAX_SSID_LENGTH (256)

// Needs to be unsafe due to input of pbuf_p from streaming channel
[[combinable]]
static unsafe void wifi_broadcom_wiced_spi_internal( // TODO: remove spi from name now?
    server interface wifi_hal_if i_hal[n_hal], size_t n_hal,
    server interface wifi_network_config_if i_conf[n_conf], size_t n_conf,
    server interface xtcp_pbuf_if i_data,
    streaming chanend c_xcore_wwd_pbuf) {

  buffers_t rx_buffers;
  buffers_init(rx_buffers);

  // Initialise with invalid interface
  int interface_mode = -1;

  while (1) {
    select {
      // WiFi HAL interface
      case i_hal[int i].init_radio():
        // Initialise driver and hardware
        debug_printf("Initialising WWD...\n");
        wwd_result_t result = wwd_management_init(WICED_COUNTRY_UNITED_KINGDOM,
                                                  NULL);
        assert(result == WWD_SUCCESS && msg("WWD initialisation failed!"));
        debug_printf("WWD initialisation complete\n");
        break;

      case i_hal[int i].get_hardware_status():
        break;

      case i_hal[int i].get_chipset_power_mode():
        break;

      case i_hal[int i].set_chipset_power_mode():
        break;

      case i_hal[int i].get_radio_tx_power():
        break;

      case i_hal[int i].set_radio_tx_power():
        break;

      case i_hal[int i].get_radio_state():
        break;

      case i_hal[int i].set_radio_state():
        break;

      case i_hal[int i].set_antenna_mode():
        break;

      case i_hal[int i].get_channel():
        break;

      case i_hal[int i].set_channel():
        break;

      // WiFi network configuration interface
      case i_conf[int i].get_mac_address(uint8_t mac_address[6]) -> wifi_res_t result:
        wiced_mac_t local_mac;
        unsafe {
          result = (wifi_res_t)xcore_wifi_get_radio_mac_address(&local_mac);
        }
        memcpy(mac_address, &local_mac, 6);
        debug_printf("WiFi MAC address: %02X:%02X:%02X:%02X:%02X:%02X\n",
                     mac_address[0], mac_address[1], mac_address[2],
                     mac_address[3], mac_address[4], mac_address[5]);
        break;

      case i_conf[int i].set_mac_address(uint8_t mac_address[6]):
        wiced_mac_t local_mac;
        memcpy(&local_mac, mac_address, sizeof(uint8_t)*6);
        xassert(interface_mode == -1);
        xcore_wifi_set_radio_mac_address(local_mac);
        break;

      case i_conf[int i].get_link_state() -> ethernet_link_state_t state:

        if (xcore_wifi_ready_to_transceive()) {
          state = ETHERNET_LINK_UP;
        } else {
          state = ETHERNET_LINK_DOWN;
        }
        break;

      case i_conf[int i].set_link_state(ethernet_link_state_t state):
        break;

      case i_conf[int i].set_networking_mode():
        break;

      case i_conf[int i].scan_for_networks() -> size_t num_networks:
        debug_printf("Internal scan_for_networks\n");
        num_networks = xcore_wifi_scan_networks();
        break;

      case i_conf[int i].join_network_by_index(size_t index,
                                      uint8_t security_key[key_length],
                                      size_t key_length) -> unsigned result:
        // debug_printf("join_network %d\n", index);
        xassert(key_length <= WIFI_MAX_KEY_LENGTH &&
               msg("Length of security key exceeds WIFI_MAX_KEY_LENGTH"));
        uint8_t local_key[WIFI_MAX_KEY_LENGTH];
        memcpy(local_key, security_key, key_length);
        result = xcore_wifi_join_network_at_index(index, local_key, key_length);
        interface_mode = result ? WWD_AP_INTERFACE : -1;
        break;

      case i_conf[int i].join_network_by_name(char name[SSID_NAME_SIZE],
                                      uint8_t security_key[key_length],
                                      size_t key_length) -> unsigned result:
        xassert(key_length <= WIFI_MAX_KEY_LENGTH &&
               msg("Length of security key exceeds WIFI_MAX_KEY_LENGTH"));
        uint8_t local_key[WIFI_MAX_KEY_LENGTH];
        memcpy(local_key, security_key, key_length);

        char local_name[SSID_NAME_SIZE];
        memcpy(local_name, name, SSID_NAME_SIZE);
        // debug_printf("join_network %s\n", local_name);

        int index = xcore_wifi_get_network_index(local_name);
        if (index != -1) {
          result = xcore_wifi_join_network_at_index(index, local_key, key_length);
          interface_mode = result ? WWD_AP_INTERFACE : -1;
        } else {
          debug_printf("Invalid network name\n");
        }
        break;

      case i_conf[int i].leave_network(size_t index):
        xassert(interface_mode == WWD_STA_INTERFACE);
        xcore_wifi_leave_network();
        interface_mode = -1;
        break;

      case i_conf[int i].start_ap(char ssid[n], const unsigned n) -> unsigned result:
        char ssid_tmp[MAX_SSID_LENGTH];
        memcpy(ssid_tmp, ssid, sizeof(char)*n);
        ssid_tmp[n] = '\0';

        unsafe {
          result = xcore_wifi_start_ap(ssid_tmp);
        }

        interface_mode = result ? WWD_AP_INTERFACE : -1;
        break;

      case i_conf[int i].stop_ap(void) -> unsigned result:
        xassert(interface_mode == WWD_AP_INTERFACE);
        result = xcore_wifi_stop_ap();
        interface_mode = -1;
        break;

      // TODO: WiFi network data interface
      case i_data.receive_packet() -> pbuf_p p:
        // debug_printf("Internal receive_packet\n");
        p = buffers_take(rx_buffers);
        if (!buffers_is_empty(rx_buffers)) {
          // If there are still packets to be consumed then notify client again
          i_data.packet_ready();
        }
        break;

      case i_data.send_packet(pbuf_p p):
        // Queue the packet for the WIFI to send it
        // debug_printf("Internal send_packet\n");
        // Increment the reference count as LWIP assumes packets have to be
        // deleted, and so does the WIFI library
        pbuf_ref(p);
        xassert(interface_mode != -1);
        wwd_network_send_ethernet_data(p, interface_mode);
        break;

      case c_xcore_wwd_pbuf :> pbuf_p p:
        debug_printf("Internal packet from WIFI\n");
        buffers_put(rx_buffers, p);
        i_data.packet_ready();
        break;
    }
  }
}

/**
 * Initialise the pointers and allocate the lock used for protection and channel
 * end used for notifications.
 * The channel end is then connected to itself so only one channel end is used
 * for notifications.
 */
unsafe static unsafe streaming chanend signals_init(signals_t &signals) {
  signals.head = 0;
  signals.tail = 0;
  signals.lock = hwlock_alloc();
  xassert(signals.lock && msg("No hardware locks available"));

  asm volatile ("getr %0, " QUOTE(XS1_RES_TYPE_CHANEND)
                    : "=r" (signals.notification_chanend));
  xassert(signals.notification_chanend && msg("No notification chanend available"));
  asm volatile ("setd res[%0], %0"
                    : // No dests
                    : "r" (signals.notification_chanend));

  // The channel end is returned so that it can be passed to the xcore_wwd task
  return (streaming chanend)signals.notification_chanend;
}

/**
 * Take the signal from the head pointer and move the head pointer
 */
xcore_wwd_control_signal_t signals_take(signals_t &signals) {
  hwlock_acquire(signals.lock);
  xassert(signals.head != signals.tail);
  xcore_wwd_control_signal_t return_value = signals.signals[signals.head];
  signals.head += 1;
  if (signals.head == NUM_SIGNALS) {
    signals.head = 0;
  }
  hwlock_release(signals.lock);
  return return_value;
}

/**
 * Insert the specified signal at the tail pointer and move the tail pointer.
 * The insertion only happens if the list is currently empty or the signal
 * type is different.
 * Returns whether the buffer was empty before the insertion.
 */
int signals_put(signals_t &signals, xcore_wwd_control_signal_t signal) {
  hwlock_acquire(signals.lock);
  int was_empty = (signals.head == signals.tail);
  if (signals.signals[signals.tail] != signal || was_empty) {
    signals.signals[signals.tail] = signal;
    signals.tail += 1;
    if (signals.tail == NUM_SIGNALS) {
      signals.tail = 0;
    }
  }
  xassert(signals.head != signals.tail);
  hwlock_release(signals.lock);
  return was_empty;
}

int signals_is_empty(signals_t &signals){
  return (signals.head == signals.tail);
}

void wifi_broadcom_wiced_builtin_spi(
    server interface wifi_hal_if i_hal[n_hal], size_t n_hal,
    server interface wifi_network_config_if i_conf[n_conf], size_t n_conf,
    server interface xtcp_pbuf_if i_data,
    wifi_spi_ports &p_spi,
    client interface input_gpio_if i_irq,
    client interface fs_basic_if i_fs) {

  unsafe streaming chanend notification_chanend;
  unsafe {
    notification_chanend = signals_init(signals);
  }

  streaming chan c_xcore_wwd_pbuf;

  par {
    // TODO: 'combine' wifi_broadcom_wiced_spi_internal and xcore_wwd
    // Start the interface task
    {
      unsafe {
        i_fs_global = i_fs;
        // Save the SPI bus details for use from wwd_spi functions
        p_wifi_bcm_wiced_spi = &p_spi;
        wifi_broadcom_wiced_spi_internal(i_hal, n_hal, i_conf, n_conf,
                                         i_data, c_xcore_wwd_pbuf);
      }
    }

    /* The SDK will expect to start this from the call to wwd_management_init
     * by attempting to spawn an RTOS thread. The xCORE implementation of the
     * WWD RTOS callbacks cannot do this, so the driver task is started
     * immediately and waits to be initialised.
     */
    {
      unsafe {
        xcore_wwd_pbuf_external = (unsafe streaming chanend)c_xcore_wwd_pbuf;
        xcore_wwd(i_irq, (streaming chanend)notification_chanend);
      }
    }
  }
}
