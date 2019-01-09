// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved
#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include "control.h"
#include "control_transport.h"
#include "resource.h"
#include "app_device.h"

void i2c_client(server i2c_slave_callback_if i_i2c, chanend c_control[1])
{
  control_init();
  control_register_resources(c_control, 1);
  while (1) {
    select {
      case i_i2c.ack_write_request(void) -> i2c_slave_ack_t resp:
        if (control_process_i2c_write_start(c_control) == CONTROL_SUCCESS)
          resp = I2C_SLAVE_ACK;
        else
          resp = I2C_SLAVE_NACK;
        break;

      case i_i2c.ack_read_request(void) -> i2c_slave_ack_t resp:
        if (control_process_i2c_read_start(c_control) == CONTROL_SUCCESS)
          resp = I2C_SLAVE_ACK;
        else
          resp = I2C_SLAVE_NACK;
        break;

      case i_i2c.master_sent_data(uint8_t data) -> i2c_slave_ack_t resp:
        if (control_process_i2c_write_data(data, c_control) == CONTROL_SUCCESS)
          resp = I2C_SLAVE_ACK;
        else {
          resp = I2C_SLAVE_NACK;
        }
        break;

      case i_i2c.master_requires_data(void) -> uint8_t data:
        control_process_i2c_read_data(data, c_control);
        break;

      case i_i2c.stop_bit(void):
        control_process_i2c_stop(c_control);
        break;

      /* not using these */
      case i_i2c.start_read_request(void): break;
      case i_i2c.start_write_request(void): break;
      case i_i2c.start_master_write(void): break;
      case i_i2c.start_master_read(void): break;
    }
  }
}

void app_device(chanend c_control)
{
  unsigned num_commands;
  int i;

  //printf("Start device app\n");
#ifdef ERRONEOUS_DEVICE
  printf("Generate errors\n");
#endif

  num_commands = 0;

  while (1) {
    int msg;
    c_control :> msg;
    switch (msg) {
      case CONTROL_REGISTER_RESOURCES:
        slave {
          c_control <: 1;
          c_control <: (control_resid_t)RESOURCE_ID;
        }
        break;

      case CONTROL_WRITE_COMMAND:
        control_resid_t resid;
        control_cmd_t cmd;
        uint8_t payload[I2C_DATA_MAX_BYTES];
        unsigned payload_len;
        control_ret_t ret = CONTROL_SUCCESS;
        slave {
          c_control :> resid;
          c_control :> cmd;
          c_control :> payload_len;
          for (i = 0; i < payload_len; i++) {
            c_control :> payload[i];
          }
        }
        num_commands++;
#ifdef ERRONEOUS_DEVICE
        if ((num_commands % 3) == 0)
          resid += 1;
#endif
        printf("%u: W %d %d %d,", num_commands, resid, cmd, payload_len);
        for (i = 0; i < payload_len; i++) {
          printf(" %02x", payload[i]);
        }
        printf("\n");
        if (resid != RESOURCE_ID) {
          printf("unrecognised resource ID %d\n", resid);
          ret = CONTROL_ERROR;
        }
        c_control <: ret;
        break;

      case CONTROL_READ_COMMAND:
        control_resid_t resid;
        control_cmd_t cmd;
        control_ret_t ret = CONTROL_SUCCESS;
        uint8_t payload[I2C_DATA_MAX_BYTES];
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
        printf("%u: R %d %d %d\n", num_commands, resid, cmd, payload_len);
        if (resid != RESOURCE_ID) {
          printf("unrecognised resource ID %d\n", resid);
          ret = CONTROL_ERROR;
        }
        else if (payload_len != 4) {
          printf("expecting 4 read bytes, not %d\n", payload_len);
          ret = CONTROL_ERROR;
        }
        else {
          payload[0] = 0x12;
          payload[1] = 0x34;
          payload[2] = 0x56;
          payload[3] = 0x78;
        }
        slave {
          for (int j = 0; j < payload_len; j++) {
            c_control <: payload[j];
          }
          c_control <: ret;
        }
        break;
    }
  }
}
