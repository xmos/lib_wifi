// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "wwd_network_interface.h"
#include "wifi_broadcom_wiced.h"
#include "lwip/pbuf.h"

void host_network_process_ethernet_data(wiced_buffer_t p,
                                        wwd_interface_t interface) {
  // increment the reference count as lwip assumes packets have to be
  // deleted, and so does the wifi library
  pbuf_ref(p);
  xcore_wiced_send_pbuf_to_internal(p);
}
