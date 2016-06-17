// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "wifi_spi.h"
#include <xs1.h>
#include <platform.h>
#include <print.h>

wifi_spi_ports spi_ports = {
    PORT_WLAN_SPI_CLK,
    PORT_WLAN_SPI_MISO,
    PORT_WLAN_SPI_MOSI,
    PORT_WLAN_SPI_CS_N,
    0, // CS on 1bit port
    on tile[1]: XS1_CLKBLK_1,
    1, // 100/4 (2*2n)
    1000,
    0
};

void test_wifi_builtin_spi() {

    wifi_spi_init(spi_ports);

#define BUF_LEN 16
    char buf[BUF_LEN];
    unsigned count = 0;

    while (1) {
        for (unsigned i=0; i  <BUF_LEN; i++) {
            buf[i] = count++;
        }
        wifi_spi_transfer(BUF_LEN, buf, spi_ports, WIFI_SPI_READ_WRITE);
        delay_milliseconds(10);
        printstr("sent\n");
    }
}

int main() {
    par {
        on tile[1]: test_wifi_builtin_spi();
    }

    return 0;
}
