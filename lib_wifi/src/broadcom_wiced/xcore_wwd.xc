// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "wifi_broadcom_wiced.h"
#include "xc_broadcom_wiced_includes.h"
#include "wwd_poll.h"
#include "wwd_rtos.h"
#include "wwd_assert.h"
#include "wwd_logging.h"
#include "gpio.h"
#include <xs1.h>

/* Cannot include wwd_rtos_interface.h as it contains prototypes which use
 * function pointers, so the required functions are externed here instead.
 */
extern "C" {
extern wwd_result_t host_rtos_init_semaphore(host_semaphore_type_t* semaphore);
extern wwd_result_t host_rtos_get_semaphore(host_semaphore_type_t* semaphore,
                                            uint32_t timeout_ms,
                                            wiced_bool_t will_set_in_isr);
extern wwd_result_t host_rtos_set_semaphore(host_semaphore_type_t* semaphore,
                                            wiced_bool_t called_from_ISR);
extern wwd_result_t host_rtos_deinit_semaphore(host_semaphore_type_t* semaphore);

extern int semaphore_increment(host_semaphore_type_t* semaphore,
                               unsigned max_count,
                               unsigned timeout_ms);
}

/* Cannot include wwd_internal.h as it contains prototypes which use
 * function pointers, so the required global is externed here instead.
 * This also requires the definition of the used types.
 */
typedef enum {
  WLAN_DOWN,
  WLAN_UP,
  WLAN_OFF
} wlan_state_t;
typedef struct {
  wlan_state_t         state;
  wiced_country_code_t country_code;
  uint32_t             keep_wlan_awake;
} wwd_wlan_status_t;
extern wwd_wlan_status_t wwd_wlan_status; // Declared in wwd_internal.c

/* The xcore_wwd task takes the xcore_wwd_ctrl_internal channel end as a
 * parameter. The other end of this channel (externed here) is declared in
 * wifi_broadcom_wiced.xc and stored as a global so that it can be used by
 * functions which it cannot be passed to (within the WICED SDK).
 */
extern unsafe streaming chanend xcore_wwd_ctrl_external;

#define WWD_THREAD_POLL_TIMEOUT (10  * XS1_TIMER_KHZ) // Milliseconds XXX: required?

static wiced_bool_t          wwd_thread_quit_flag = WICED_FALSE;
static wiced_bool_t          wwd_inited           = WICED_FALSE;
host_semaphore_type_t wwd_transceive_semaphore;
static wiced_bool_t          wwd_bus_interrupt    = WICED_FALSE;
static unsigned int          wwd_thread_poll_timeout;

/** TODO: document (brief) */
wwd_result_t wwd_thread_init() {
  wwd_result_t retval;

  retval = wwd_sdpcm_init();
  if (retval != WWD_SUCCESS) {
    WPRINT_WWD_ERROR(("Could not initialize SDPCM codec\n")); // TODO: replace with debug_printf
    return retval;
  }

  // Create the event flag which signals the WWD thread needs to wake up
  retval = host_rtos_init_semaphore(&wwd_transceive_semaphore);
  if (retval != WWD_SUCCESS) {
    WPRINT_WWD_ERROR(("Could not initialize WWD thread semaphore\n")); // TODO: replace with debug_printf
    return retval;
  }

  /* Rather than call host_rtos_create_thread() here, send start signal to
   * logical core waiting to run the WWD task.
   */
// TODO: remove #if
#if 0
  xcore_wwd_send_control_signal(XCORE_WWD_START);
#else
  unsafe {
    xcore_wwd_ctrl_external <: XCORE_WWD_START;
  }
#endif

  wwd_inited = WICED_TRUE;
  return WWD_SUCCESS;
}

/** TODO: document (brief) */
int8_t wwd_thread_send_one_packet() {
  wiced_buffer_t tmp_buf_hnd = NULL;

  if (wwd_sdpcm_get_packet_to_send(&tmp_buf_hnd) != WWD_SUCCESS) {
    // TODO: debug print
    // Failed to get a packet
    return 0;
  }

  // Ensure the wlan backplane bus is up
  if (wwd_bus_ensure_is_up() != WWD_SUCCESS) {
    wiced_assert("Could not bring bus back up", 0 != 0); // TODO: replace with fail()
    host_buffer_release(tmp_buf_hnd, WWD_NETWORK_TX);
    return 0;
  }

  WPRINT_WWD_DEBUG(("Wcd:> Sending pkt 0x%08X\n\r", (unsigned int)tmp_buf_hnd)); // TODO: replace with debug_printf
  if (wwd_bus_send_buffer(tmp_buf_hnd) != WWD_SUCCESS) {
    return 0;
  }
  return 1;
}

/** TODO: document (brief) */
int8_t wwd_thread_receive_one_packet() {
  // Check if there is a packet ready to be received
  wiced_buffer_t recv_buffer;
  if (wwd_bus_read_frame(&recv_buffer) != WWD_SUCCESS) {
    // Failed to read a packet
    return 0;
  }

  if (recv_buffer != NULL) { // Could be null if it was only a credit update
    WWD_LOG(("Wcd:< Rcvd pkt 0x%08X\n", (unsigned int)recv_buffer)); // TODO: replace with debug_printf

    // Send received buffer up to SDPCM layer
    wwd_sdpcm_process_rx_packet(recv_buffer);
  }
  return 1;
}

// XXX: host_rtos_get_semaphore() does not call wwd_thread_poll_all() as it makes use of the semaphore timeout
#if 0
/** TODO: document (brief) */
int8_t wwd_thread_poll_all() {
  int8_t result = 0;
  result |= wwd_thread_send_one_packet();
  result |= wwd_thread_receive_one_packet();
  return result;
}
#endif

/** TODO: document (brief) */
void wwd_thread_quit() {
  wwd_result_t result;

  // Signal main thread and wake it
  wwd_thread_quit_flag = WICED_TRUE;
  result = host_rtos_set_semaphore(&wwd_transceive_semaphore, WICED_FALSE);

  if (result == WWD_SUCCESS) {
    /* Rather than call host_rtos_join_thread() here, wait for stopped signal
     * from logical core running the WWD task.
     */
// TODO: remove #if
#if 0
    if (xcore_receive_control_signal() != XCORE_WWD_STOPPED) {
      fail("Unexpected signal received");
    }
#else
    xcore_wwd_control_signal_t received_signal;
    unsafe {
      xcore_wwd_ctrl_external :> received_signal;
    }
    if (received_signal != XCORE_WWD_STOPPED) {
      fail("Unexpected signal received");
    }
#endif
  }
}

/** TODO: document (brief) */
void wwd_thread_notify() {
  // Just wake up the main thread and let it deal with the data
  if (wwd_inited == WICED_TRUE) {
    host_rtos_set_semaphore(&wwd_transceive_semaphore, WICED_FALSE);
  }
}

/** TODO: document (brief)
 * xCORE implementation of wwd_thread_func() from wwd_thread.c
 */
static void wwd_thread_func() {
  uint8_t rx_status;
  uint8_t tx_status;
  wwd_result_t result;

  // Check if we were woken by interrupt
  if ((wwd_bus_interrupt == WICED_TRUE) || (WWD_BUS_USE_STATUS_REPORT_SCHEME)) {
    wwd_bus_interrupt = WICED_FALSE;

    // Check if the interrupt indicated there is a packet to read
    if (wwd_bus_packet_available_to_read() != 0) {
      // Receive all available packets
      do {
        rx_status = wwd_thread_receive_one_packet();
      } while ( rx_status != 0 );
    }
  }

  // Send all the packets in the queue
  do {
      tx_status = wwd_thread_send_one_packet();
  } while (tx_status != 0);

  // Check if we have run out of bus credits
  if (wWd_sdpcm_get_available_credits() == 0) {
    // Keep poking the WLAN until it gives us more credits
    result = wwd_bus_poke_wlan();
    wiced_assert("Poking failed!", result == WWD_SUCCESS);
    REFERENCE_DEBUG_ONLY_VARIABLE(result); // XXX: keep?

    result = host_rtos_get_semaphore(&wwd_transceive_semaphore,
                                     (uint32_t)100, WICED_FALSE);
  } else {
    // Put the bus to sleep and wait for something else to do
    if (wwd_wlan_status.keep_wlan_awake == 0) {
      result = wwd_bus_allow_wlan_bus_to_sleep();
      wiced_assert("Error setting wlan sleep", result == WWD_SUCCESS);
      REFERENCE_DEBUG_ONLY_VARIABLE(result);
    }
    result = host_rtos_get_semaphore(&wwd_transceive_semaphore,
                                     (uint32_t)WWD_THREAD_POLL_TIMEOUT,
                                     WICED_FALSE);
  }
  REFERENCE_DEBUG_ONLY_VARIABLE(result);
  wiced_assert("Could not get wwd sleep semaphore\n",
               (result == WWD_SUCCESS) || (result == WWD_TIMEOUT));

  wwd_thread_poll_timeout += WWD_THREAD_POLL_TIMEOUT; // XXX: might want to have a long and short timeout that can be set here

  if (wwd_thread_quit_flag == WICED_TRUE) {
    // Reset the quit flag
    wwd_thread_quit_flag = WICED_FALSE;

    // Delete the semaphore
    host_rtos_deinit_semaphore(&wwd_transceive_semaphore);

    wwd_sdpcm_quit();
    wwd_inited = WICED_FALSE;

    /* Rather than call host_rtos_finish_thread() here, send stopped signal to
     * logical core waiting for the WWD task to join.
     */
// TODO: remove #if
#if 0
    xcore_wwd_send_control_signal(XCORE_WWD_STOPPED);
#else
    unsafe {
      xcore_wwd_ctrl_external <: XCORE_WWD_STOPPED;
    }
#endif
  }
}

/** TODO: document (brief) */
void xcore_wwd_send_control_signal(xcore_wwd_control_signal_t signal_to_send) {
  unsafe {
    xcore_wwd_ctrl_external <: signal_to_send;
  }
}

/** TODO: document (brief) */
xcore_wwd_control_signal_t xcore_receive_control_signal() {
  xcore_wwd_control_signal_t received_signal;
  unsafe {
    xcore_wwd_ctrl_external :> received_signal;
  }
  return received_signal;
}

/** TODO: document (brief) */
[[combinable]]
void xcore_wwd(client interface input_gpio_if i_irq,
               streaming chanend xcore_wwd_ctrl_internal) {
  timer t_periodic;

  // Get the initial timer value
  t_periodic :> wwd_thread_poll_timeout;

  // Configure IRQ input to event when it is asserted
  i_irq.event_when_pins_eq(1); // TODO: define a value to use here?

  while (1) {
    select {
      /* TODO: document (brief) */
      case xcore_wwd_ctrl_internal :> xcore_wwd_control_signal_t ctrl_sig:
        switch (ctrl_sig) {
          case XCORE_WWD_START:
            // XXX: call wwd_thread_func(); here?
            break;
          case XCORE_WWD_SEMAPHORE_INCREMENT:
            if (wwd_inited) {
              wwd_thread_func();
            }
            break;
        }
        break;

      /* BCM WWD implementation is notified when the IRQ line is asserted by
       * calling wwd_thread_notify_irq(), but we can just perform the
       * required actions immediately.
       */
      case wwd_inited => i_irq.event():
        // Configure IRQ input to event again next time it's asserted
        i_irq.input();
        i_irq.event_when_pins_eq(1); // TODO: define a value to use here?

        wwd_bus_interrupt = WICED_TRUE;

        // Just wake up the main thread and let it deal with the data
        /* FIXME: would be nice to remove this special case and call
         * host_rtos_set_semaphore again
         * (revert commit ffde131653cd5b680bc1205be2fb6292c9bb9943)
         */
        if (semaphore_increment(&wwd_transceive_semaphore,
                                WIFI_BCM_WWD_SEMAPHORE_MAX_VAL, 0)) {
          wwd_thread_func();
        }
        break;

#if 0
      /* TODO: document (brief)
       * XXX: might not need timer events
       */
      case wwd_inited => t_periodic when timerafter(wwd_thread_poll_timeout) :> void:
        wwd_thread_func();
        break;
#endif

      // TODO: check for notification from wifi_broadcom_wifi_spi core for packets to write - interface to "application interface" task
    }
  }
}
