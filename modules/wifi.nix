{
  config,
  lib,
  pkgs,
  ...
}:
{ sops.secrets."wifi/phone/ssid" = {
  };

  sops.secrets."wifi/phone/psk" = {
  };

  sops.secrets."wifi/home/ssid" = {
  };

  sops.secrets."wifi/home/psk" = {
  };

  networking.networkmanager = {

    # generated in /run/NetworkManager/system-connections/
    ensureProfiles = {

      environmentFiles = [
        config.sops.secrets."wifi/phone/ssid".path
        config.sops.secrets."wifi/phone/psk".path
        config.sops.secrets."wifi/home/ssid".path
        config.sops.secrets."wifi/home/psk".path
      ];

      profiles = {
        "phone" = {
          connection = {
            id = "phone";
            type = "wifi";
            autoconnect = true;
          };
          wifi = {
            mode = "infrastructure";
            ssid = "$PHONE_SSID";
          };
          wifi-security = {
            key-mgmt = "wpa-psk";
            psk = "$PHONE_PSK";
          };
          ipv4 = {
            method = "auto";
          };
          ipv6 = {
            method = "auto";
            addr-gen-mode = "stable-privacy";
          };
        };

        "home" = {
          connection = {
            id = "home";
            type = "wifi";
            autoconnect = true;
          };
          wifi = {
            mode = "infrastructure";
            ssid = "$HOME_SSID";
          };
          wifi-security = {
            key-mgmt = "wpa-psk";
            psk = "$HOME_PSK";
          };
          ipv4 = {
            method = "auto";
          };
          ipv6 = {
            method = "auto";
            addr-gen-mode = "stable-privacy";
          };
        };
      };
    };
  };
}