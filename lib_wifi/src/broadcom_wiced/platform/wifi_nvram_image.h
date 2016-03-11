// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef __wifi_nvram_image_h__
#define __wifi_nvram_image_h__

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

#if WIFI_MODULE_MURATA_SN8000 == 1
#include "murata_sn8000_nvram_image.h"
#else
#error "No NVRAM image included"
#endif

#ifdef __cplusplus
}
#endif // __cplusplus

#endif // __wifi_nvram_image_h__
