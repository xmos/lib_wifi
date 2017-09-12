# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling.

TARGET = WIFI-MIC-ARRAY-1V0

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name

APP_NAME =

XTCP_STACK=LWIP
# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
#
#    XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
#
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.

GEN_XCC_FLAGS = -g -Os -fxscope -DLWIP_XTCP=1 -DDEBUG_PRINT_ENABLE_ALL=1 -DXASSERT_ENABLE_ASSERTIONS=1 -DXASSERT_ENABLE_DEBUG=1 -fno-inline-functions

XCC_FLAGS = # Using GEN_XCC_FLAGS to allow for XCC_C_FLAGS to tidy lib_xtcp
XCC_C_FLAGS = $(GEN_XCC_FLAGS) -Wno-ignored-attributes -Wno-typedef-redefinition
XCC_XC_FLAGS = $(GEN_XCC_FLAGS) -Wno-unknown-pragmas
# TODO: remove above warning suppressions
XCC_MAP_FLAGS = -report -lquadflash

ENABLE_STAGED_BUILD = 1
# TODO: remove above line

# The USED_MODULES variable lists other module used by the application.

USED_MODULES = lib_wifi lib_logging lib_gpio lib_filesystem lib_http lib_dns lib_dhcp

EXCLUDE_FILES = main.cpp

#=============================================================================
# The following part of the Makefile includes the common build infrastructure
# for compiling XMOS applications. You should not need to edit below here.

XMOS_MAKE_PATH ?= ../..
include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common
