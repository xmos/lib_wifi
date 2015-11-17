#include "platform/wwd_bus_interface.h"
#include "platform/wwd_spi_interface.h"
#include "platform_config.h"
#include "wifi_broadcom_wiced.h"

/* XXX: there is mutual recursion in WICED/.../SPI/wwd_bus_protocol.c:
 * wwd_bus_transfer_bytes() calls wwd_read_register_value() and vice versa.
 * To get correct resource usage information we will need to reimplement all
 * functions in wwd_bus_protocol.c, all but the above functions can be
 * provided unchanged in src/broadcom_wiced/platform/spi/wwd_bus_protocol.c
 */

// TODO: ensure GPIO_0 is used to select SPI mode - Add pull-up on SN8000 GPIO_0

wwd_result_t host_platform_bus_init() {
  // SPI and GPIO (for IRQ line) components started from par, so already ready
  return WWD_SUCCESS;
}

wwd_result_t host_platform_bus_deinit() {
  // No action needed
  return WWD_SUCCESS;
}

wwd_result_t host_platform_spi_transfer(wwd_bus_transfer_direction_t dir,
                                        uint8_t* buffer,
                                        uint16_t buffer_length) {
  // Must call an xC function to perform SPI transfer as lib_spi uses interfaces
  xcore_wiced_spi_transfer(dir, buffer, buffer_length);
  return WWD_SUCCESS;
}

wwd_result_t host_platform_bus_enable_interrupt() {
  // GPIO component used for IRQ started from par, so already ready
  return WWD_SUCCESS;
}

wwd_result_t host_platform_bus_disable_interrupt() {
  // No action needed
  return WWD_SUCCESS;
}
