#include "wifi.h"
#include <platform.h>
#include "spi.h"
#include "gpio.h"

#include "debug_print.h"

// These ports are used for the SPI master
out buffered port:32 p_sclk  = on tile[0]:   XS1_PORT_1I;
out          port    p_ss[1] = on tile[0]: { XS1_PORT_1J };
in  buffered port:32 p_miso  = on tile[0]:   XS1_PORT_1K;
out buffered port:32 p_mosi  = on tile[0]:   XS1_PORT_1L;

// Input port used for IRQ interrupt line
in port p_irq = on tile[0]: XS1_PORT_1A;

void application(client interface wifi_hal_if i_hal,
         client interface wifi_network_config_if i_conf,
         client interface wifi_network_data_if i_data) {
  debug_printf("tmp\n");
}

int main(void) {
  interface wifi_hal_if i_hal[1];
  interface wifi_network_config_if i_conf[1];
  interface wifi_network_data_if i_data[1];
  interface spi_master_if i_spi[1];
  interface input_gpio_if i_inputs[1];

  par {
    wifi_broadcom_wiced_spi(i_hal, 1, i_conf, 1, i_data, 1,
                            i_spi[0], 0,
                            i_inputs[0]);
    application(i_hal[0], i_conf[0], i_data[0]);
    spi_master(i_spi, 1, p_sclk, p_mosi, p_miso, p_ss, 1, null);
    input_gpio_with_events(i_inputs, 1, p_irq, null);
  }

  return 0;
}
