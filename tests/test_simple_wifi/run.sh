#!/bin/bash
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

xgdb bin/test_simple_wifi.xe -ex="connect --xscope-port 127.0.0.1:10234" -ex="load" \
 -ex="set args \"$1\" \"$2\"" \
 -ex="c"
