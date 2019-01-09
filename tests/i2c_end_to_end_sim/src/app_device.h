// Copyright (c) 2016-2017, XMOS Ltd, All rights reserved
#ifndef __app_dev_h__
#define __app_dev_h__

#include "i2c.h"
#include "control.h"

void i2c_client(server i2c_slave_callback_if i_i2c, chanend c_control[1]);
void app_device(chanend i_control);

#endif // __app_dev_h__
