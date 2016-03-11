#!/bin/bash
XCC_PATH=`which xcc`
TOOLS_PATH=`dirname $XCC_PATH`

gcc -g main.cpp -I $TOOLS_PATH/../include $TOOLS_PATH/../lib/xscope_endpoint.so -o host
