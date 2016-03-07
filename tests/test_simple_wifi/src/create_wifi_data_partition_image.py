#!/usr/bin/env python
import os.path
import subprocess


if __name__ == "__main__":
    image_creator_path = os.path.join('..', '..', '..', '..', 'lib_filesystem',
                                      'lib_filesystem', 'disk_image_creators',
                                      'fat', 'fat_image_creator')

    bcm_firmware_path = os.path.join('..', '..', '..', '..', 'lib_wifi',
                                     'lib_wifi', 'src', 'broadcom_wiced', 'sdk',
                                     'WICED-SDK-3.3.1', 'resources', 'firmware',
                                     '43362', '43362A2.bin')

    output_image_path = os.path.join('..', 'wifi_bcm_43362A2')

    test_xe_path = os.path.join('..', 'bin', 'test_simple_wifi.xe')

    # Run image builder
    subprocess.check_call([image_creator_path, output_image_path,
                           bcm_firmware_path],
                           cwd=os.path.dirname(os.path.realpath(__file__)))

    # Run xflash to write FAT image to data partition of flash
    subprocess.check_call(['xflash', test_xe_path,
                           '--boot-partition-size', '1000000',
                           '--data', output_image_path],
                          cwd=os.path.dirname(os.path.realpath(__file__)))
