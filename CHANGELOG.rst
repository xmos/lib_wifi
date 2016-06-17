WiFi library change log
=======================

0.0.3
-----

  * Updated to support xCORE WiFi Microphone Array 1V1 hardware. Note: the xCORE
    WiFi Microphone Array 1V0 hardware is no longer supported.
  * Reorder wifi_broadcom_wiced_builtin_spi() parameters to simplify switching
    between transports in WiFi applications in the future

0.0.2
-----

  * Update boot partition size in create_wifi_data_partion_image.py script to
    avoid sector alignment warning from xFLASH
  * Update test_simple_wifi run_wrapper host application to handle passwords
    containing semicolons and empty strings

0.0.1
-----

  * Initial development

  * Changes to dependencies:

    - lib_crypto: Added dependency 1.0.0

    - lib_ethernet: Added dependency 3.2.0

    - lib_filesystem: Added dependency 0.0.1

    - lib_gpio: Added dependency 1.0.1

    - lib_locks: Added dependency 2.0.2

    - lib_logging: Added dependency 2.0.1

    - lib_otpinfo: Added dependency 2.0.1

    - lib_xassert: Added dependency 2.0.1

    - lib_xtcp: Added dependency 5.1.0

