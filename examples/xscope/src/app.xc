// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved
#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include "control.h"
#include "mic_array_board_support.h"
#include "app.h"

void app(chanend c_control, client interface mabs_led_button_if i_leds_buttons)
{
  unsigned num_commands;
  int i;

  printf("started\n");
#ifdef ERRONEOUS_DEVICE
  printf("generate errors\n");
#endif

  num_commands = 0;

  while (1) {
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
        uint8_t payload[64];
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
        printf("%u: W %d %d %d,", num_commands, resid, cmd, payload_len);
        for (i = 0; i < payload_len; i++) {
          printf(" %02x", payload[i]);
        }
        printf("\n");
        if (resid != RESOURCE_ID) {
          printf("unrecognised resource ID %d\n", resid);
          ret = CONTROL_ERROR;
          break;
        }
        for (i = 0; i < MIC_BOARD_SUPPORT_LED_COUNT; i++){
          if (i < payload[0]) i_leds_buttons.set_led_brightness(i, 255);
          else i_leds_buttons.set_led_brightness(i, 0);
        }
        ret = CONTROL_SUCCESS;
        c_control <: ret;
        break;

      case CONTROL_READ_COMMAND:
        control_resid_t resid;
        control_cmd_t cmd;
        control_ret_t ret;
        uint8_t payload[64];
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
          break;
        }
        if (payload_len != 4) {
          printf("expecting 4 read bytes, not %d\n", payload_len);
          ret = CONTROL_ERROR;
          break;
        }
        unsigned button;
        mabs_button_state_t button_state;
        i_leds_buttons.get_button_event(button, button_state);
        printf("button, button_state= %d, %d\n", button, button_state);
        payload[0] = button;
        payload[1] = button_state;
        payload[2] = 0x56;
        payload[3] = 0x78;
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
}
