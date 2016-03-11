SDK requirements
----------------

Place the uncompressed WICED SDK directory in here, your directory tree should
be as follows:

lib_wifi/
└── lib_wifi
    ├── api/
    ├── doc/
    └── src/
        └── broadcom_wiced/
            ├── network/
            ├── platform/
            ├── rtos/
            └── sdk/
                ├── WICED-SDK-3.3.1/     <- Place uncompressed SDK download here
                ├── sdk_requirements.rst <- This file
                └── xcore_compat.patch   <- Patch file to apply to SDK source

Apply the patch file using either of the following commands:
  "patch -p1 -i xcore_compat.patch"
  "git apply --whitespace=nowarn xcore_compat.patch"
