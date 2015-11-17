#ifndef __wifi_wwd_rtos_h__
#define __wifi_wwd_rtos_h__

#include <stdint.h>

#define RTOS_HIGHER_PRIORTIY_THAN(x) (x)
#define RTOS_LOWER_PRIORTIY_THAN(x)  (x)
#define RTOS_LOWEST_PRIORITY         (0)
#define RTOS_HIGHEST_PRIORITY        (0)
#define RTOS_DEFAULT_THREAD_PRIORITY (0)

#define RTOS_USE_STATIC_THREAD_STACK // XXX: can be removed when using xcore_wwd()

#define WIFI_BCM_WWD_SEMAPHORE_INIT_VAL (0) // TODO: document
#define WIFI_BCM_WWD_SEMAPHORE_MAX_VAL (UINT8_MAX) // TODO: document

typedef unsigned char host_semaphore_type_t; // FIXME: this was just created as a place holder
typedef unsigned char host_thread_type_t; // FIXME: this was just created as a place holder
typedef unsigned char host_queue_type_t; // FIXME: this was just created as a place holder

typedef unsigned int xcore_wwd_notification_t; // TODO: document

#define WWD_THREAD_STACK_SIZE 1024 // XXX: just made this up! Can be removed when using xcore_wwd()

#endif // __wifi_wwd_rtos_h__
