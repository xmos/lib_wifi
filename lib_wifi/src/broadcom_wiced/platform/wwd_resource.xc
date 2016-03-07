// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "xc_broadcom_wiced_includes.h"
#include "wwd_assert.h"
#include "filesystem.h"

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
      char filename[] = FIRMWARE_FILENAME;
      result = i_fs_global.open(filename, sizeof(filename));
      if (result != FS_RES_OK) {
        return RESOURCE_FILE_OPEN_FAIL;
      }
      file_opened = 1;

      result = i_fs_global.size(file_size);
      if (result != FS_RES_OK) {
        return RESOURCE_UNSUPPORTED;
      }
    }
  }
  return RESOURCE_SUCCESS;
}

wwd_result_t host_platform_resource_size(wwd_resource_t resource,
                                         uint32_t* unsafe size_out) {

  resource_result_t result = open_file_if_required(resource);
  if (result == RESOURCE_SUCCESS) {
    unsafe {
      *size_out = (uint32_t)file_size;
    }
    return WWD_SUCCESS;
  }

  return result;
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

  resource_result_t res_result = open_file_if_required(resource);
  if (res_result == RESOURCE_SUCCESS) {
    unsafe {
      fs_result_t fs_result = FS_RES_NOT_OPENED;

      // Seek to the required point in the file
      fs_result = i_fs_global.seek(offset, 1); // Start seek from the beginning
      if (fs_result != FS_RES_OK) {
        // TODO: handle error
      }
      /* Attempt to read buffer_size bytes from the file into buffer,
       * returning the actual number of bytes read in size_out
       */
      size_t local_size_out = *size_out;
      fs_result = i_fs_global.read((uint8_t *)buffer, buffer_size, buffer_size,
                                   local_size_out);
      *size_out = local_size_out;
      if (fs_result != FS_RES_OK) {
        // TODO: handle error
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
}

#endif // WWD_DIRECT_RESOURCES
