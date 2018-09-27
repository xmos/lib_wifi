// Copyright (c) 2015-2017, XMOS Ltd, All rights reserved
#include "xc_broadcom_wiced_includes.h"
#include "wwd_assert.h"
#include "filesystem.h"
#include "wifi_nvram_image.h"
#include <string.h>

#undef DEBUG_UNIT
#define DEBUG_UNIT WIFI_WWD_RESOURCES_DEBUG
#include "debug_print.h"

// Cannot include wiced_resource.h, so a result macro is defined here
#ifndef RESULT_ENUM
#define RESULT_ENUM(prefix, name, value)  prefix ## name = (value)
#endif

/* These Enum result values are for Resource errors
 * Values: 4000 - 4999
 */
#define RESOURCE_RESULT_LIST(prefix) \
  RESULT_ENUM(prefix, SUCCESS,        0),    /**< Success */ \
  RESULT_ENUM(prefix, UNSUPPORTED,    7),    /**< Unsupported function */ \
  RESULT_ENUM(prefix, OFFSET_TOO_BIG, 4001), /**< Offset past end of resource */ \
  RESULT_ENUM(prefix, FILE_OPEN_FAIL, 4002), /**< Failed to open resource file */ \
  RESULT_ENUM(prefix, FILE_SEEK_FAIL, 4003), /**< Failed to seek to requested offset in resource file */ \
  RESULT_ENUM(prefix, FILE_READ_FAIL, 4004), /**< Failed to read resource file */

/**
 * Result type for resource function
 */
typedef enum {
    RESOURCE_RESULT_LIST(RESOURCE_)
} resource_result_t;

#define STRINGIZE(s) #s
#define STRINGIZE2(s) STRINGIZE(s)
#define FIRMWARE_FILENAME STRINGIZE2(WICED_WLAN_CHIP) STRINGIZE2(WICED_WLAN_CHIP_REVISION) ".BIN"

// TODO: add build options to enable P2P configuration (for Soft APs), must load the "-p2p" firmware image for the 43362 radio here

#define NVRAM_SIZE           sizeof(wifi_nvram_image)
#define NVRAM_IMAGE_VARIABLE wifi_nvram_image

extern unsafe client interface fs_basic_if i_fs_global;

int file_opened = 0;
size_t file_size = 0;

resource_result_t open_file_if_required(wwd_resource_t resource) {

  wiced_assert("Only WLAN firmware resources are supported",
               WWD_RESOURCE_WLAN_FIRMWARE == resource);
  if (resource != WWD_RESOURCE_WLAN_FIRMWARE) {
    return RESOURCE_UNSUPPORTED;
  }

  unsafe {
    fs_result_t result = FS_RES_NOT_OPENED;

    if (!file_opened) {
      // If the file is not yet open, assume the filesystem is not yet mounted
      result = i_fs_global.mount();
      if (result != FS_RES_OK) {
        debug_printf("Failed to mount filesystem with code %d\n", result);
        return RESOURCE_FILE_OPEN_FAIL;
      }
      char filename[] = FIRMWARE_FILENAME;
      result = i_fs_global.open(filename, sizeof(filename));
      if (result != FS_RES_OK) {
        debug_printf("Failed to open firmware file %s\n", filename);
        return RESOURCE_FILE_OPEN_FAIL;
      }
      file_opened = 1;

      result = i_fs_global.size(file_size);
      if (result != FS_RES_OK) {
        debug_printf("Failed to get size of firmware file\n");
        return RESOURCE_UNSUPPORTED;
      }
      debug_printf("Opened firmware file of size %d bytes\n", file_size);
    }
  }
  return RESOURCE_SUCCESS;
}

wwd_result_t host_platform_resource_size(wwd_resource_t resource,
                                         uint32_t* unsafe size_out) {

  if (resource == WWD_RESOURCE_WLAN_FIRMWARE) {
    resource_result_t result = open_file_if_required(resource);
    if (result == RESOURCE_SUCCESS) {
      unsafe {
        *size_out = (uint32_t)file_size;
      }
      return WWD_SUCCESS;
    }
    return result;

  }  else if (resource == WWD_RESOURCE_WLAN_NVRAM) {
    unsafe {
      *size_out = NVRAM_SIZE;
    }
    return WWD_SUCCESS;

  } else {
    fail("Unknown resource type requested\n");
    return RESOURCE_UNSUPPORTED;
  }
}

#if WWD_DIRECT_RESOURCES

#error WWD_DIRECT_RESOURCES are not supported on xCORE

wwd_result_t host_platform_resource_read_direct(wwd_resource_t resource,
                                                const void** ptr_out) {
  // TODO: remove if resources will only ever be indirect
  return WWD_SUCCESS;
}

#else

wwd_result_t host_platform_resource_read_indirect(wwd_resource_t resource,
                                                  uint32_t offset,
                                                  void* unsafe buffer,
                                                  uint32_t buffer_size,
                                                  uint32_t* unsafe size_out) {
  if (resource == WWD_RESOURCE_WLAN_FIRMWARE) {
    resource_result_t res_result = open_file_if_required(resource);
    if (res_result == RESOURCE_SUCCESS) {
      unsafe {
        fs_result_t fs_result = FS_RES_NOT_OPENED;

        // Seek to the required point in the file
        fs_result = i_fs_global.seek(offset, 1); // Start seek from the beginning
        if (fs_result != FS_RES_OK) {
          debug_printf("Failed to seek to offset %d\n", offset);
          // TODO: handle error
        }
        /* Attempt to read buffer_size bytes from the file into buffer,
         * returning the actual number of bytes read in size_out
         */
        size_t local_size_out = *size_out;
        // debug_printf("Attempting to read %d bytes... ", buffer_size);
        fs_result = i_fs_global.read((uint8_t *)buffer, buffer_size, buffer_size,
                                     local_size_out);
        *size_out = local_size_out;
        // debug_printf("read %d bytes\n", local_size_out);
        if (fs_result != FS_RES_OK) {
          fail("Error reading from filesystem\n");
          return WWD_PARTIAL_RESULTS;
        }

        /* If the end of the file has been reached (i.e. if (
         * (offset + size_out) == file_size)), it could now be closed and
         * 'file_opened' set back to zero.
         * However there is no need (or method) to close files when using the
         * fs_basic_if interface, so there is nothing more to do.
         */
      }
      return WWD_SUCCESS;
    }
    return res_result;

  } else if (resource == WWD_RESOURCE_WLAN_NVRAM) {
    unsafe {
      *size_out = MIN( buffer_size, NVRAM_SIZE - offset );
      memcpy( buffer, &NVRAM_IMAGE_VARIABLE[ offset ], *size_out );
    }
    return WWD_SUCCESS;

  } else {
    fail("Unknown resource type requested\n");
    return RESOURCE_UNSUPPORTED;
  }
}

#endif // WWD_DIRECT_RESOURCES
