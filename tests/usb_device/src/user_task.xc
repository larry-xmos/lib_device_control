// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved
#include <xs1.h>
#include <stdint.h>
#include <stdio.h>
#include "control.h"
#include "control_transport.h"
#include "user_task.h"

void user_task(chanend i, chanend c)
{
  while (1) {
    int msg;
    i :> msg;
    switch (msg) {
      case CONTROL_REGISTER_RESOURCES:
        unsigned num_resources;
        control_resid_t resources[MAX_RESOURCES_PER_INTERFACE];
        c :> num_resources;
        for (int k = 0; k < num_resources; k++) {
          unsigned word;
          c :> word;
          resources[k] = word;
        }
        slave {
          i <: num_resources;
          for (int k = 0; k < num_resources; k++) {
            i <: resources[k];
          }
        }
        break;

      case CONTROL_WRITE_COMMAND:
        control_resid_t resid;
        control_cmd_t cmd;
        uint8_t payload[I2C_DATA_MAX_BYTES];
        unsigned payload_len;
        slave {
          i :> resid;
          i :> cmd;
          i :> payload_len;
          for (int j = 0; j < payload_len; j++) {
            i :> payload[j];
          }
        }
        c <: cmd;
        c <: resid;
        c <: payload_len;
        for (int j = 0; j < payload_len; j++) {
          c <: payload[j];
        }
        i <: (control_ret_t)CONTROL_SUCCESS;
        break;

      case CONTROL_READ_COMMAND:
        control_resid_t resid;
        control_cmd_t cmd;
        uint8_t payload[I2C_DATA_MAX_BYTES];
        unsigned payload_len;
        slave {
          i :> resid;
          i :> cmd;
          i :> payload_len;
        }
        c <: cmd;
        c <: resid;
        c <: payload_len;
        for (int j = 0; j < payload_len; j++) {
          c :> payload[j];
        }
        slave {
          for (int j = 0; j < payload_len; j++) {
            i <: payload[j];
          }
          i <: (control_ret_t)CONTROL_SUCCESS;
        }
        break;
    }
  }
}
