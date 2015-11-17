#include "wwd_resource_interface.h"
#include <flash.h>

wwd_result_t host_platform_resource_size(wwd_resource_t resource,
                                         uint32_t* size_out) {
  // TODO: implement - assuming that petit fatfs will be used here
  /*
   * connect to flash device
   * get the size of the data partition, to sanity check all is in order
   * read file size of radio fw from file system
   * disconnect from flash device
   */
  return WWD_SUCCESS;
}

#if WWD_DIRECT_RESOURCES

#error WWD_DIRECT_RESOURCES are not supported on xCORE

wwd_result_t host_platform_resource_read_direct(wwd_resource_t resource,
                                                const void** ptr_out ) {
  // TODO: remove if resources will only ever be indirect
  return WWD_SUCCESS;
}

#else

wwd_result_t host_platform_resource_read_indirect(wwd_resource_t resource,
                                                  uint32_t offset, void* buffer,
                                                  uint32_t buffer_size,
                                                  uint32_t* size_out ) {
  // TODO: implement - assuming that petit fatfs will be used here
  /*
   * connect to flash device
   * get the size of the data partition, to sanity check all is in order
   * read file size of radio fw from file system
   * fill buffer with data from offset bytes into the file to the smaller of buffer_size or resource size
   * disconnect from flash device
   */
  return WWD_SUCCESS;
}

#endif // WWD_DIRECT_RESOURCES
