// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "wifi_spi.h"
#include <xclib.h>

static unsigned compute_port_ticks(unsigned nanoseconds,
                                   unsigned clock_divide) {
  // Default clock tick is the reference clock, if divided then it is scaled by
  // 2*clock_divide
  unsigned port_tick_nanoseconds = clock_divide ? 10 * clock_divide * 2 : 10;

  // Do a ceiling function to ensure the delay is always at least that requested
  return (nanoseconds + port_tick_nanoseconds - 1) / port_tick_nanoseconds;
}

static unsigned compute_port_value(wifi_spi_ports &p,
                                   uint32_t p_ss_bit,
                                   uint32_t bit_value) {
  // Get the current state of the port
  unsigned current_port_value = peek(p.cs);
  // Zero the p_ss_bit
  unsigned new_port_value = (current_port_value & ~(1 << p_ss_bit));
  // Or desired bit value into p_ss_bit
  return new_port_value | (bit_value << p_ss_bit);
}

void wifi_spi_drive_cs_port_now(wifi_spi_ports &p,
                                uint32_t p_ss_bit,
                                uint32_t bit_value) {
  unsigned new_port_value = compute_port_value(p, p_ss_bit, bit_value);

  p.cs <: new_port_value;
}

void wifi_spi_drive_cs_port_at_time(wifi_spi_ports &p,
                                    uint32_t p_ss_bit,
                                    uint32_t bit_value,
                                    unsigned *time) {
  unsigned new_port_value = compute_port_value(p, p_ss_bit, bit_value);

  p.cs @ *time <: new_port_value;
}

void wifi_spi_drive_cs_port_get_time(wifi_spi_ports &p,
                                     uint32_t p_ss_bit,
                                     uint32_t bit_value,
                                     unsigned *time) {
  unsigned new_port_value = compute_port_value(p, p_ss_bit, bit_value);

  p.cs <: new_port_value @ *time;
}

void wifi_spi_init(wifi_spi_ports &p){
  stop_clock(p.cb);
  configure_clock_ref(p.cb, p.clock_divide);
  configure_out_port(p.clk, p.cb, 0xFFFFFFFF);
  configure_in_port(p.miso, p.cb);
  configure_out_port(p.mosi, p.cb, 0);
  set_port_clock(p.cs, p.cb);
  start_clock(p.cb);
  wifi_spi_drive_cs_port_now(p, p.cs_port_bit, 1);
  p.cs_to_data_delay_ticks = compute_port_ticks(p.cs_to_data_delay_ns,
                                                p.clock_divide);
}

void wifi_spi_transfer(unsigned num_bytes, char *buffer, wifi_spi_ports &p,
                       wifi_spi_direction_t direction) {
  // Prepare the outgoing data
  // TODO: optimise the data reversal
  for (int i = 0; i < num_bytes; i++) {
    buffer[i] = byterev(bitrev(buffer[i]));
  }

  unsigned start_time;
  wifi_spi_drive_cs_port_get_time(p, p.cs_port_bit, 0, &start_time);

  unsigned port_time = start_time + p.cs_to_data_delay_ticks;

  partout_timed(p.clk, 16, 0xAAAA, port_time);
  partout_timed(p.mosi, 16, zip(buffer[0], buffer[0], 0), port_time);

  // porttime_p.miso = port_time+15
  asm volatile ("setpt res[%0], %1":: "r"(p.miso), "r"(port_time+15));

  // shiftcount_p.miso = 16
  asm volatile ("setpsc res[%0], %1":: "r"(p.miso), "r"(16));

  unsigned i;
  unsigned tmp;
  for (i = 1; i < num_bytes; i++) {
    partout(p.clk, 16, 0xAAAA);
    partout(p.mosi, 16, zip(buffer[i], buffer[i], 0));

    // p.miso :> tmp
    asm volatile ("in %0, res[%1]": "=r"(tmp) : "r"(p.miso));

    // shiftcount_p.miso = 16
    asm volatile ("setpsc res[%0], %1":: "r"(p.miso), "r"(16));
    if (direction != WIFI_SPI_WRITE) {
      {buffer[i-1], void} = unzip(tmp >> 16, 0);
    }
  }

  // p.miso :> tmp
  asm volatile ("in %0, res[%1]": "=r"(tmp) : "r"(p.miso));
  if (direction != WIFI_SPI_WRITE) {
    {buffer[i-1], void} = unzip(tmp >> 16, 0);
  }

  delay_microseconds(10); // Makes BCM Wifi work better... TODO: make configurable
  wifi_spi_drive_cs_port_now(p, p.cs_port_bit, 1);
  delay_microseconds(5); // Makes BCM Wifi work better... TODO: make configurable

  // Prepare the received data
  // TODO: optimise the data reversal
  for (int i = 0; i < num_bytes; i++) {
    buffer[i] = byterev(bitrev(buffer[i]));
  }
}
