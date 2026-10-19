_:

{
  services.home-assistant = {
    enable = false; # doesn't build!?
    extraComponents = [
      # Components required to complete the onboarding
      "esphome"
      "met"
      "radio_browser"
      "tasmota"
      "google_translate"
      "prusalink"
      "cast"
      "spotify"
    ];
    config = {
      # Includes dependencies for a basic setup
      # https://www.home-assistant.io/integrations/default_config/
      default_config = { };
      mqtt = {
        climate = [
          {
            name = "Emelies Heizung";
            modes = [
              "off"
              "heat"
              "auto"
            ];
            min_temp = 5;
            max_temp = 26;
            temp_step = 0.5;
            precision = 0.1;
            mode_command_topic = "cmnd/tasmota_D84500/EQ3/001A221B9574/mode";
            temperature_command_topic = "cmnd/tasmota_D84500/EQ3/001A221B9574/settemp";
            temperature_state_topic = "stat/EQ3/001A221B9574";
            temperature_state_template = "{{ value_json.temp }}";
            mode_state_topic = "stat/EQ3/001A221B9574";
            mode_state_template = "{{ value_json.hassmode }}";
            #current_temperature_topic = "tele/tasmota_D84500/SENSOR";
            # current_temperature_template: '{{ value_json["AM2301"].Temperature - 4.2 }}'
            #current_temperature_template = "{{ value_json[\"AM2301\"].Temperature }}";
            #current_humidity_topic = "tele/tasmota_D84500/SENSOR";
            #current_humidity_template = "{{ value_json[\"AM2301\"].Humidity }}";
          }
        ];
        sensor = [
          {
            name = "Palme_Boden";
            state_topic = "Palme/soil";
            unique_id = "mqtt_palme_soil";
            device_class = "moisture";
          }
        ];
      };
    };
  };
  networking.firewall.allowedTCPPorts = [
    8123 # Home Assistant
    1883 # Mosquitto
  ];

  services.mosquitto = {
    enable = true;
    # port = 1883;
    listeners = [
      {
        users.root = {
          acl = [
            "readwrite #"
            #"topic write tasmota/discovery/#"
          ];
          #omitPasswordAuth = true;
          password = "root123";
          #settings.allow_anonymous = true;
        };
      }
      #      {
      #        users.DVES_USER = {
      #          acl = [
      #            "readwrite #"
      #          ];
      #          #omitPasswordAuth = true;
      #          password = "root123";
      #          #settings.allow_anonymous = true;
      #        };
      #      }
    ];
  };
}
