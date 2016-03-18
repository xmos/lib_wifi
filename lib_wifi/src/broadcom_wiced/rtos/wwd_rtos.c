// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "wwd_rtos.h"
#include "wwd_rtos_interface.h"
#include "wwd_poll.h"
#include "wifi_broadcom_wiced.h"
#include <stdbool.h>
#include <time.h>
#include <timer.h>

// TODO: Ensure assertions can be disabled, define debug unit here?
#include "xassert.h"

wwd_result_t host_rtos_create_thread(host_thread_type_t* thread,
                                     void(*entry_function)(uint32_t),
                                     const char* name, void* stack,
                                     uint32_t stack_size, uint32_t priority) {
  /* A single thread is started by the WICED SDK when (only) WWD is used.
   * To avoid the use of function pointers and process forking outside of xC we
   * do not create a thread here.
   *
   * wwd_thread_init will send a signal via a channel to start the WWD task
   * running, rather than calling this function.
   */
   fail("Trying to create an RTOS thread!");

  return WWD_SUCCESS;
}

wwd_result_t host_rtos_create_thread_with_arg(host_thread_type_t* thread,
                                              void(*entry_function)(uint32_t),
                                              const char* name, void* stack,
                                              uint32_t stack_size,
                                              uint32_t priority, uint32_t arg) {
  /* Not attempting to do anything here as wwd_thread_init() would use
   * host_rtos_create_thread() instead, and no other thread creation is
   * expected.
   */
  fail("Trying to create an unexpected RTOS thread!");

  return WWD_SUCCESS;
}

wwd_result_t host_rtos_finish_thread(host_thread_type_t* thread) {
  /* The logical core (thread) running WWD will not attempt to terminate itself,
   * it will instead enter a deinitialised waiting state (ready to restart
   * the WWD when required).
   *
   * wwd_thread_func() will send a signal via a channel to indicate when it has
   * stopped, rather than calling this function.
   */
   fail("Trying to finish an RTOS thread!");

  return WWD_SUCCESS;
}

wwd_result_t host_rtos_join_thread(host_thread_type_t* thread) {
  /* The logical core (thread) running WWD will not join when the task is
   * stopped, it will enter a deinitialised waiting state instead.
   * Upon entry to this state, it will send a 'stopped' signal.
   *
   * wwd_thread_func() will send a signal via a channel directly, rather than
   * calling this function.
   */

  return WWD_SUCCESS;
}

wwd_result_t host_rtos_delete_terminated_thread(host_thread_type_t* thread) {
  // No action required

  return WWD_SUCCESS;
}

// TODO: move semaphores to lib_locks
// The hardware lock is declared in newlib's lock.h module.
extern unsigned __libc_hwlock;

static inline void hwlock_acquire()
{
  __asm__ __volatile__ ("in %0, res[%0]"
                        : /* no output */
                        : "r" (__libc_hwlock)
                        : "memory");
}

static inline void hwlock_release()
{
  __asm__ __volatile__ ("out res[%0], %0"
                        : /* no output */
                        : "r" (__libc_hwlock)
                        : "memory");
}

static bool conditional_increment(host_semaphore_type_t* ptr, unsigned max) {
  bool success = false;
  hwlock_acquire();
  int tmp = *ptr;
  if (tmp < max) {
    *ptr = tmp + 1;
    success = true;
  }
  hwlock_release();
  return success;
}

static bool conditional_decrement(host_semaphore_type_t* ptr, unsigned min) {
  bool success = false;
  hwlock_acquire();
  int tmp = *ptr;
  if (tmp > min) {
    *ptr = tmp - 1;
    success = true;
  }
  hwlock_release();
  return success;
}

int semaphore_increment(host_semaphore_type_t* semaphore,
                         unsigned max_count,
                         unsigned timeout_ms) {
  clock_t current_time, exit_time;

  exit_time = clock();
  exit_time += (timeout_ms * XS1_TIMER_KHZ); // Scale timeout up to timer ticks
  while (!conditional_increment(semaphore, max_count)) {
    if (timeout_ms == 0) {
      return 0; // Fail immediately
    } else {
      delay_microseconds(1); // Yield processing power
      current_time = clock();
      if (((int)(exit_time - current_time) < 0) &&
          (timeout_ms != NEVER_TIMEOUT)) {
        return 0; // Timed out
      }
    }
  }
  return 1;
}

static bool semaphore_decrement(host_semaphore_type_t* semaphore,
                                unsigned min_count,
                                unsigned timeout_ms) {
  clock_t current_time, exit_time;

  exit_time = clock();
  exit_time += (timeout_ms * XS1_TIMER_KHZ); // Scale timeout up to timer ticks
  while (!conditional_decrement(semaphore, min_count)) {
    if (timeout_ms == 0) {
      return false; // Fail immediately
    } else {
      delay_microseconds(1); // Yield processing power
      current_time = clock();
      if (((int)(exit_time - current_time) < 0) &&
          (timeout_ms != NEVER_TIMEOUT)) {
        return false; // Timed out
      }
    }
  }
  return true;
}

wwd_result_t host_rtos_init_semaphore(host_semaphore_type_t* semaphore) {
  *semaphore = WIFI_BCM_WWD_SEMAPHORE_INIT_VAL;
  return WWD_SUCCESS;
}

extern host_semaphore_type_t wwd_transceive_semaphore;

wwd_result_t host_rtos_get_semaphore(host_semaphore_type_t* semaphore,
                                     uint32_t timeout_ms,
                                     wiced_bool_t will_set_in_isr) {
  if (semaphore_decrement(semaphore, WIFI_BCM_WWD_SEMAPHORE_INIT_VAL,
                          timeout_ms)) {
    // XXX: special case to handle wwd_transceive_semaphore reaching zero?
    return WWD_SUCCESS;
  } else {
    return WWD_TIMEOUT;
  }
}

wwd_result_t host_rtos_set_semaphore(host_semaphore_type_t* semaphore,
                                     wiced_bool_t called_from_ISR) {
  if (semaphore_increment(semaphore, WIFI_BCM_WWD_SEMAPHORE_MAX_VAL, 0)) {
    /* Special handling of wwd_transceive_semaphore to cause the xcore_wwd()
     * task to event when this semaphore is set
     */
    if (semaphore == &wwd_transceive_semaphore) {
      xcore_wwd_send_control_signal(XCORE_WWD_SEMAPHORE_INCREMENT);
    }
    return WWD_SUCCESS;
  } else {
    fail("Unable to set semaphore\n");
    return WWD_SEMAPHORE_ERROR;
  }
}

wwd_result_t host_rtos_deinit_semaphore(host_semaphore_type_t* semaphore) {
  // No structures to free
  return WWD_SUCCESS;
}

extern unsigned xcore_get_ticks();

wwd_time_t host_rtos_get_time() {
  // Convert ticks to ms
  return (wwd_time_t)(xcore_get_ticks() / 100000);
}

wwd_result_t host_rtos_delay_milliseconds(uint32_t num_ms) {
  delay_milliseconds(num_ms);
  return WWD_SUCCESS;
}
