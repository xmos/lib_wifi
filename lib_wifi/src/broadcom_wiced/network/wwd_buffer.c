#include "wwd_buffer_interface.h"
#include "wwd_network_constants.h"
#include "wwd_assert.h"
#include <stddef.h>
#include <timer.h>
#include "lwip/memp.h"
#include "lwip/pbuf.h"

// XXX: can be removed now we're using LWIP buffers
// static wiced_buffer_t internal_buffer = 0;
// static uint16_t internal_buffer_max_size = 0;
// static uint16_t internal_buffer_curr_size = 0;

wwd_result_t host_buffer_init(void *native_arg) {
  // No action required
  return WWD_SUCCESS;
}

wwd_result_t host_buffer_check_leaked() {
  wiced_assert("pbuf pool Buffer leakage", memp_in_use(MEMP_PBUF_POOL) == 0);
  wiced_assert("pbuf ref/rom Buffer leakage", memp_in_use(MEMP_PBUF) == 0);
  return WWD_SUCCESS;
}

wwd_result_t host_buffer_get(wiced_buffer_t *buffer, wwd_buffer_dir_t direction,
                             unsigned short size, wiced_bool_t wait) {
  wiced_assert("Error: Invalid buffer size\n", size != 0);

  *buffer = NULL;

  if (size > (unsigned short) WICED_LINK_MTU) {
    WPRINT_NETWORK_DEBUG(("Attempt to allocate a buffer larger than the MTU of the link\n"));
    return WWD_BUFFER_UNAVAILABLE_PERMANENT;
  }

  do {
    *buffer = pbuf_alloc(PBUF_RAW, size, PBUF_POOL);
  } while ((*buffer == NULL) &&
           (wait == WICED_TRUE) &&
           (delay_ticks(1), 1 == 1));
  if (*buffer == NULL) {
    debug_printf("Failed to allocate packet buffer\n");
    return WWD_BUFFER_UNAVAILABLE_TEMPORARY;
  }
  return WWD_SUCCESS;
}

void host_buffer_release(wiced_buffer_t buffer, wwd_buffer_dir_t direction) {
  wiced_assert("Error: Invalid buffer\n", buffer != NULL);
  pbuf_free(buffer); /* Ignore returned number of freed segments since TCP
                      * packets will still be referenced by LWIP after release
                      * by WICED
                      */
}

uint8_t* host_buffer_get_current_piece_data_pointer(wiced_buffer_t buffer) {
  wiced_assert("Error: Invalid buffer\n", buffer != NULL);
  return (uint8_t*) buffer->payload;
}

uint16_t host_buffer_get_current_piece_size(wiced_buffer_t buffer) {
  wiced_assert("Error: Invalid buffer\n", buffer != NULL);
  return (uint16_t) buffer->len;
}

wiced_buffer_t host_buffer_get_next_piece(wiced_buffer_t buffer) {
  wiced_assert("Error: Invalid buffer\n", buffer != NULL);
  return buffer->next;
}

wwd_result_t host_buffer_add_remove_at_front(wiced_buffer_t * buffer,
                                             int32_t add_remove_amount) {
  wiced_assert("Error: Invalid buffer\n", buffer != NULL);
  if ((u8_t)0 != pbuf_header(*buffer, (s16_t)(-add_remove_amount))) {
    WPRINT_NETWORK_DEBUG(("Failed to move pointer - usually because not enough space at front of buffer\n"));
    return WWD_BUFFER_POINTER_MOVE_ERROR;
  }
  return WWD_SUCCESS;
}

wwd_result_t host_buffer_set_size(wiced_buffer_t buffer, unsigned short size) {
  if (size > (unsigned short)WICED_LINK_MTU) {
    WPRINT_NETWORK_ERROR(("Attempt to set a length larger than the MTU of the link\n"));
    return WWD_BUFFER_SIZE_SET_ERROR;
  }

  buffer->tot_len = size;
  buffer->len = size;

  return WWD_SUCCESS;
}
