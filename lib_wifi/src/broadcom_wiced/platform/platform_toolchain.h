// Copyright (c) 2016, XMOS Ltd, All rights reserved
#ifndef __wifi_platform_toolchain_h__
#define __wifi_platform_toolchain_h__

#ifndef WEAK
#define WEAK __attribute__((weak))
#endif

// TODO: remove - WWD debugging can just use printf
// TODO: Ensure prints can be disabled, define debug unit here?
// #include "debug_print.h"
// // Override the print macro in the WICED SDK as it uses printf
// #include "wwd_debug.h"
// #undef WPRINT_MACRO
// #define WPRINT_MACRO(args) debug_printf args // WICED prints include parenthesis

#endif // __wifi_platform_toolchain_h__
