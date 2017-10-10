// Copyright (c) 2015-2017, XMOS Ltd, All rights reserved
#include "client_app.h"

#define MAX_MESSAGE_SIZE (1500)
#define MQTT_DEFAULT_PORT (1883)
#define MQTT_BROKER_ADDR {192, 168, 2, 1}

void client_startup(client xtcp_if * unsafe i_xtcp, mqtt_client_state_t &cs)
{
  unsafe {
    xtcp_ipaddr_t broker_addr = MQTT_BROKER_ADDR;
    const int command_timeout_ms = 1000;

    mqtt_init_client_state(cs, 0, broker_addr, MQTT_DEFAULT_PORT, i_xtcp,
      command_timeout_ms
    );
  }

  mqtt_wait_for_broker(cs);

  MQTTPacket_connectData data = MQTTPacket_connectData_initializer;
  data.willFlag = 0;
  data.MQTTVersion = 3;
  data.keepAliveInterval = 10;
  data.cleansession = 1;
  unsafe {
    data.clientID.cstring = "unique_id";
    data.username.cstring = "use-token-auth";
    data.password.cstring = "";
  }

  mqtt_connect(cs, data);
}

void client_app(client xtcp_if i_xtcp)
{
  mqtt_client_state_t mqtt_state;
  char buffer[MAX_MESSAGE_SIZE];
  MQTTMessage message = { QOS2, 0, 0, 0 };

  unsafe {
    client_startup(&i_xtcp, mqtt_state);
    message.payload = (void*)buffer;
  }

  mqtt_subscribe(mqtt_state, "test_topic", QOS2, 0);

  while(mqtt_state.broker_state != MQTT_STATE_DISCONNECTED) {
    select {
      // Handle some other events.

      default:
        // Handle mqtt events
        mqtt_handle_connection(mqtt_state);

        // If we have recieved a publish
        if (mqtt_state.packet_type == PUBLISH) {
          debug_printf("Recieved message of size %d\n", mqtt_state.message.payloadlen);
          mqtt_publish(mqtt_state, "another_topic", message);
        }
        break;
    }
  }
}
