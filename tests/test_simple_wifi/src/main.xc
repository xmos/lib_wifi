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

#define USE_ASYNC_SPI 0

out port p_lpo_sleep_clk = on tile[0]: XS1_PORT_4D; // Bit 3

// These ports are used for the SPI master
out buffered port:32 p_sclk  = on tile[1]:   XS1_PORT_1N;
out          port    p_ss[1] = on tile[1]: { XS1_PORT_4E }; // Bit 0
in  buffered port:32 p_miso  = on tile[1]:   XS1_PORT_1M;
out buffered port:32 p_mosi  = on tile[1]:   XS1_PORT_1L;

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

        } else if (strcmp(buffer, "show") == 0) {
          size_t num_networks = i_conf.get_num_networks();
          debug_printf("Printing %d networks\n", num_networks);
          for (size_t i = 0; i < num_networks; i++) {
            const wiced_ssid_t * unsafe ssid = i_conf.get_network_ssid(i);
            // The SSID name is not guaranteed to be null-terminated
            printstr("Network");
            printint(i);
            printstr(": SSID: ");
            unsafe {
              for (size_t c = 0; c < ssid->length; c++) {
                printchar(ssid->value[c]);
              }
            }
            printstr("\n");
          }
        } else if (strcmp(buffer, "join") == 0) {
          xscope_data_from_host(xscope_data_in, buffer, bytesRead);
          xassert(bytesRead && msg("Scan index data too short\n"));
          size_t index = strtoul(buffer, NULL, 0);
          xscope_data_from_host(xscope_data_in, buffer, bytesRead);
          xassert(bytesRead <= WIFI_MAX_KEY_LENGTH &&
                  msg("Security key data too long\n"));
          // -1 due to \n being sent
          i_conf.join_network(index, buffer, bytesRead-1);
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
  interface spi_master_async_if i_spi[1];
#else
  interface spi_master_if i_spi[1];
#endif
  interface input_gpio_if i_inputs[1];
  interface fs_basic_if i_fs[1];
  chan c_xscope_data_in;

  chan c_xtcp[1];

  par {
    xscope_host_data(c_xscope_data_in);

    on tile[1]:                process_xscope(c_xscope_data_in, i_conf[CONFIG_XSCOPE]);
#if USE_ASYNC_SPI
    on tile[1]:                wifi_broadcom_wiced_asyc_spi(i_hal, 2, i_conf, NUM_CONFIG,
                                                            i_data, i_spi[0], 0,
                                                            i_inputs[0], i_fs[0]);
#else
    on tile[1]:                wifi_broadcom_wiced_spi(i_hal, 2, i_conf, NUM_CONFIG,
                                                       i_data, i_spi[0], 0,
                                                       i_inputs[0], i_fs[0]);
#endif
    on tile[1]:                application(i_hal[0], i_conf[CONFIG_APP]);
#if USE_ASYNC_SPI
    on tile[1]: spi_master_async(i_spi, 1, p_sclk, p_mosi, p_miso, p_ss, 1,
                                 clk0, clk1);
#else
    on tile[1]: [[distribute]] spi_master(i_spi, 1, p_sclk, p_mosi, p_miso,
                                          p_ss, 1, null);
#endif
    on tile[1]:                input_gpio_with_events(i_inputs, 1, p_irq, null);
    on tile[1]:                xtcp_lwip_wifi(c_xtcp, 1, i_hal[1],
                                              i_conf[CONFIG_XTCP],
                                              i_data, ipconfig);
    // on tile[0]:                sleep_clock_gen();
    on tile[0]:                filesystem_tasks(i_fs);
  }

  return 0;
}
