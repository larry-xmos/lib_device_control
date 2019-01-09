// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <assert.h>
#include "control.h"
#include "control_transport.h"
#include "app.h"

void app(chanend c_control)
{
  unsigned num_commands;
  int i;

  const unsigned char rx_expected_payload[4] = {0xaa, 0xff, 0x55, 0xed};

  printf("started\n");
#ifdef ERRONEOUS_DEVICE
  printf("generate errors\n");
#endif

  num_commands = 0;

  while (num_commands!=8) {
    int msg;
    c_control :> msg;
    switch (msg) {
      case CONTROL_REGISTER_RESOURCES:
        slave {
          c_control <: 1;
          c_control <: (control_ret_t)RESOURCE_ID;
        }
        break;

      case CONTROL_WRITE_COMMAND:
        control_resid_t resid;
        control_cmd_t cmd;
        control_ret_t ret;
        uint8_t payload[USB_DATA_MAX_BYTES];
        unsigned payload_len;
        slave {
          c_control :> resid;
          c_control :> cmd;
          c_control :> payload_len;
          for (int j = 0; j < payload_len; j++) {
            c_control :> payload[j];
          }
        }
        num_commands++;
#ifdef ERRONEOUS_DEVICE
        if ((num_commands % 3) == 0)
          resid += 1;
#endif
        printf("%u: W %d %d %d,\t=", num_commands, resid, cmd, payload_len);
        for (i = 0; i < payload_len; i++) {
          printf(" %02x", payload[i]);
          if (payload[i] != rx_expected_payload[i]) {
            printf("\nERROR - incorrect data received - expecting 0x%x\n", rx_expected_payload[i]);
            ret = CONTROL_ERROR;
            break;
          }
        }
        printf("\n");
        if (resid != RESOURCE_ID) {
          printf("unrecognised resource ID %d\n", resid);
          ret = CONTROL_ERROR;
          break;
        }
        ret = CONTROL_SUCCESS;
        c_control <: ret;
        break;

      case CONTROL_READ_COMMAND:
        control_resid_t resid;
        control_cmd_t cmd;
        control_ret_t ret;
        uint8_t payload[USB_DATA_MAX_BYTES];
        unsigned payload_len;
        slave {
          c_control :> resid;
          c_control :> cmd;
          c_control :> payload_len;
        }
        num_commands++;
#ifdef ERRONEOUS_DEVICE
        if ((num_commands % 3) == 0)
          resid += 1;
#endif
        payload[0] = 0x12;
        payload[1] = 0x34;
        payload[2] = 0x56;
        payload[3] = 0x78;
        printf("%u: R %d %d %d,\t=", num_commands, resid, cmd, payload_len);
        for (i = 0; i < payload_len; i++) {
          printf(" %02x", payload[i]);
        }
        printf("\n");
        if (resid != RESOURCE_ID) {
          printf("unrecognised resource ID %d\n", resid);
          ret = CONTROL_ERROR;
          break;
        }
        if (payload_len != 4) {
          printf("ERROR - expecting 4 read bytes, not %d\n", payload_len);
          ret = CONTROL_ERROR;
          break;
        }
        ret = CONTROL_SUCCESS;
        slave {
          for (int j = 0; j < payload_len; j++) {
            c_control <: payload[j];
          }
          c_control <: ret;
        }
        break;
    }
  }
  _Exit(0);
}
