// Copyright (c) 2015-2017, XMOS Ltd, All rights reserved
#include "wwd_network_interface.h"
#include "wifi_broadcom_wiced.h"

void host_network_process_ethernet_data(wiced_buffer_t p,
                                        wwd_interface_t interface) {
  xcore_wiced_send_pbuf_to_internal(p);
}
