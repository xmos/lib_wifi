#include "wifi.h"
#include <platform.h>
#include "spi.h"
#include "gpio.h"
#include <quadflash.h>
#include "qspi_flash_storage_media.h"
#include "filesystem.h"

#include "debug_print.h"

// These ports are used for the SPI master
out buffered port:32 p_sclk  = on tile[0]:   XS1_PORT_1I;
out          port    p_ss[1] = on tile[0]: { XS1_PORT_1J };
in  buffered port:32 p_miso  = on tile[0]:   XS1_PORT_1K;
out buffered port:32 p_mosi  = on tile[0]:   XS1_PORT_1L;

// Input port used for IRQ interrupt line
in port p_irq = on tile[0]: XS1_PORT_1A;

fl_QSPIPorts qspi_flash_ports = {
  PORT_SQI_CS,
  PORT_SQI_SCLK,
  PORT_SQI_SIO,
  on tile[0]: XS1_CLKBLK_1
};

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
  interface fs_basic_if i_fs[1];
  interface fs_storage_media_if i_media;
  fl_QuadDeviceSpec qspi_spec = FL_QUADDEVICE_SPANSION_S25FL116K;

  par {
    wifi_broadcom_wiced_spi(i_hal, 1, i_conf, 1, i_data, 1,
                            i_spi[0], 0,
                            i_inputs[0],
                            i_fs[0]);
    application(i_hal[0], i_conf[0], i_data[0]);
    spi_master(i_spi, 1, p_sclk, p_mosi, p_miso, p_ss, 1, null);
    input_gpio_with_events(i_inputs, 1, p_irq, null);
    qspi_flash_fs_media(i_media, qspi_flash_ports, qspi_spec, 512);
    filesystem_basic(i_fs, 1, FS_FORMAT_FAT12, i_media);
  }

  return 0;
}
