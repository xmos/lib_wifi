#ifndef __wifi_platform_assert_h__
#define __wifi_platform_assert_h__

// TODO: Ensure assertions can be disabled, define debug unit here?
#include "xassert.h"

#define WICED_ASSERTION_FAIL_ACTION() fail(""); //TODO: add message?

#endif // __wifi_platform_assert_h__
