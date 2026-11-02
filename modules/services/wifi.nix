{
  flake.modules.nixos.wifi =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      envFile = "/run/nm-wifi.env";
    in
    {

      sops.secrets."wifi/phone/ssid" = {
      };

      sops.secrets."wifi/phone/psk" = {
      };

      sops.secrets."wifi/home/ssid" = {
      };

      sops.secrets."wifi/home/psk" = {
      };

      # generated in /run/NetworkManager/system-connections/
      # The module does `EnvironmentFile = environmentFiles` + envsubst on the
      # profile values, i.e. it needs KEY=VALUE dotenv lines - the raw sops
      # secret files parse as no assignments at all, so $PHONE_SSID/$HOME_SSID
      # expanded empty and NetworkManager rejected every profile with
      # "SSID length is out of range <1-32> bytes" (x41/day). Assemble a proper
      # dotenv file from the sops secret paths first, and feed only that.
      networking.networkmanager.ensureProfiles = {

        environmentFiles = [
          envFile
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

      systemd.services."nm-wifi-env" = {
        description = "Assemble the dotenv env file NetworkManager ensureProfiles needs";
        wantedBy = [ "NetworkManager-ensure-profiles.service" ];
        before = [ "NetworkManager-ensure-profiles.service" ];
        after = [ "sops-nix.service" ];
        requires = [ "sops-nix.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainOnExit = true;
          ExecStart = pkgs.writeShellScript "nm-wifi-env" ''
            set -euo pipefail
            umask 077
            : > ${envFile}
            printf 'PHONE_SSID=%s\n' "$(cat ${config.sops.secrets."wifi/phone/ssid".path})" >> ${envFile}
            printf 'PHONE_PSK=%s\n' "$(cat ${config.sops.secrets."wifi/phone/psk".path})" >> ${envFile}
            printf 'HOME_SSID=%s\n' "$(cat ${config.sops.secrets."wifi/home/ssid".path})" >> ${envFile}
            printf 'HOME_PSK=%s\n' "$(cat ${config.sops.secrets."wifi/home/psk".path})" >> ${envFile}
          '';
        };
      };
    };
}
