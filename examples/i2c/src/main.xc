// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved
#include <platform.h>
#include <stdio.h>
#include <syscall.h>
#include <timer.h>
#include "i2c.h"
#include "control.h"
#include "mic_array_board_support.h"
#include "app.h"

on tile[1]: port p_scl = XS1_PORT_1A; /* X1D0 mic array board resistor R60 and also ETH_RXCLK */
on tile[1]: port p_sda = XS1_PORT_1B; /* X1D1 mic array board resistor R57 and also ETH_TXCLK */
on tile[1]: out port p_eth_phy_reset = XS1_PORT_4F; /* X1D29, bit 1 of port 4F */

on tile[0]: mabs_led_ports_t p_leds = on tile[0]: MIC_BOARD_SUPPORT_LED_PORTS;
on tile[0]: in port p_buttons = MIC_BOARD_SUPPORT_BUTTON_PORTS;

const char i2c_device_addr = 123;

[[combinable]]
void i2c_client(server i2c_slave_callback_if i_i2c, chanend c_control[1])
{
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

int main(void)
{
  i2c_slave_callback_if i_i2c;
  chan c_control[1];
  interface mabs_led_button_if i_leds_buttons[1];

  par {
    on tile[0]: par {
      app(c_control[0], i_leds_buttons[0]);
      mabs_button_and_led_server(i_leds_buttons, 1, p_leds, p_buttons);
      }
    on tile[1]: {
      /* hold Ethernet PHY in reset to ensure it is not driving clock */
      p_eth_phy_reset <: 0;
      control_init();
      control_register_resources(c_control, 1);
      /* bug 17317 - [[combine]] */
      par {
        i2c_client(i_i2c, c_control);
        i2c_slave(i_i2c, p_scl, p_sda, i2c_device_addr);
      }
    }
  }
  return 0;
}
