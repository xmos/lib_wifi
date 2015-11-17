#ifndef __wifi_broadcom_wiced_h__
#define __wifi_broadcom_wiced_h__

#include "xc2compat.h"
#include <stdint.h>
#include "xc_broadcom_wiced_includes.h"
#include "gpio.h"

/** TODO: document (brief) */
typedef enum {
  XCORE_WWD_START,              ///< TODO: document (brief)
  XCORE_WWD_STOPPED,            ///< TODO: document (brief)
  XCORE_WWD_SEMAPHORE_INCREMENT ///< TODO: document (brief)
} xcore_wwd_control_signal_t;

/** TODO: document (brief) */
unsafe void xcore_wiced_spi_transfer(wwd_bus_transfer_direction_t direction,
                                     uint8_t * unsafe buffer,
                                     uint16_t buffer_length);

/** TODO: document (brief) */
void xcore_wwd_send_control_signal(xcore_wwd_control_signal_t signal_to_send);

/** TODO: document (brief) */
xcore_wwd_control_signal_t xcore_wwd_receive_control_signal();

#if __XC__

/** TODO: document (brief) */
[[combinable]]
void xcore_wwd(client interface input_gpio_if i_irq,
               chanend xcore_wwd_ctrl_internal);

#endif // __XC__

#endif // __wifi_broadcom_wiced_h__
