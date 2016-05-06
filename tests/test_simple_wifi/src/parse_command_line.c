// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include "parse_command_line.h"

void parse_command_line(size_t index, char arg[]) {
  char buf[256];
  int argc = _get_cmdline(buf, 256);
  char **argv = (char **)&buf;
  if (index < argc) {
    strcpy(arg, argv[index]);
  }
}

