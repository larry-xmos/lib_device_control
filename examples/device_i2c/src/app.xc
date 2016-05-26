// Copyright (c) 2016, XMOS Ltd, All rights reserved
#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include "control.h"
#include "app.h"

void app(server interface control i_control)
{
  unsigned num_commands;
  int i;

  printf("started\n");

  num_commands = 0;

  while (1) {
    select {
      case i_control.register_resources(resource_id resources[MAX_RESOURCES_PER_INTERFACE],
                                        unsigned &num_resources):
        resources[0] = RESOURCE_ID;
        num_resources = 1;
        break;

      case i_control.write_command(resource_id r, command_code c, const uint8_t data[n], unsigned n):
        assert(r == RESOURCE_ID);
        printf("%u: W 0x%08x %d %d,", num_commands, r, c, n);
        for (i = 0; i < n; i++) {
          printf(" %02x", data[i]);
        }
        printf("\n");
        num_commands++;
        break;

      case i_control.read_command(resource_id r, command_code c, uint8_t data[n], unsigned n):
        assert(r == RESOURCE_ID);
        printf("%u: R 0x%08x %d %d,", num_commands, r, c, n);
        assert(n == 4);
        data[0] = 0x12;
        data[1] = 0x34;
        data[2] = 0x56;
        data[3] = 0x78;
        printf("\n");
        num_commands++;
        break;
    }
  }
}