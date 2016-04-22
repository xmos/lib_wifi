// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef __wifi_spi_h__
#define __wifi_spi_h__

#include <xs1.h>
#include <stdint.h>
#include <stddef.h>

typedef struct {
  out buffered port:32 clk;
  in buffered port:32 miso; // Data driven at double the SPI clock rate
  out buffered port:32 mosi; // Data driven at double the SPI clock rate
  out port cs;
  size_t cs_port_bit;
  clock cb;
  unsigned clock_divide;
  unsigned cs_to_data_delay_ns;
  unsigned cs_to_data_delay_ticks;
} wifi_spi_ports;

typedef enum wifi_spi_port_time_mode_t {
  WIFI_SPI_CS_DRIVE_NOW,
  WIFI_SPI_CS_DRIVE_AT_TIME,
  WIFI_SPI_CS_GET_TIMESTAMP
} wifi_spi_port_time_mode_t;

typedef enum wifi_spi_direction_t {
  WIFI_SPI_READ,
  WIFI_SPI_WRITE,
  WIFI_SPI_READ_WRITE
} wifi_spi_direction_t;

void wifi_spi_init(wifi_spi_ports &p);

void wifi_spi_transfer(unsigned num_bytes, char *buffer, wifi_spi_ports &p,
                       wifi_spi_direction_t direction);

void wifi_spi_drive_cs_port_now(wifi_spi_ports &p,
                                uint32_t p_ss_bit,
                                uint32_t bit_value);

void wifi_spi_drive_cs_port_at_time(wifi_spi_ports &p,
                                    uint32_t p_ss_bit,
                                    uint32_t bit_value,
                                    unsigned *time);

void wifi_spi_drive_cs_port_get_time(wifi_spi_ports &p,
                                     uint32_t p_ss_bit,
                                     uint32_t bit_value,
                                     unsigned *time);

#endif // __wifi_spi_h__
