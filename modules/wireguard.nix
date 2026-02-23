{ config, pkgs, ... }:

{
  networking.nat.enable = true;
  networking.nat.externalInterface = "eth0";
  networking.nat.internalInterfaces = [ "wg0" "nebula.mesh" ];
  networking.nat.enableIPv6 = true;
  networking.firewall.allowedUDPPorts = [ 55025 ];
  sops.secrets."wireguard/private" = {
    sopsFile = ../secrets/services/wireguard/secrets.yaml;
  };

  sops.secrets."wireguard/peer/test1" = {
    sopsFile = ../secrets/services/wireguard/secrets.yaml;
  };

  sops.secrets."wireguard/peer/ks273fb" = {
    sopsFile = ../secrets/services/wireguard/secrets.yaml;
  };

  sops.secrets."wireguard/peer/giusi" = {
    sopsFile = ../secrets/services/wireguard/secrets.yaml;
  };

  # Enable Wireguard
  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {

      listenPort = 55025;
      # Determines the IP address and subnet of the client's end of the tunnel interface.
      ips = [
        "10.66.66.1/24"
        "fd42:42:42::1/64"
      ];

      # Path to the private key file.
      #
      # Note: The private key can also be included inline via the privateKey option,
      # but this makes the private key world-readable; thus, using privateKeyFile is
      # recommended.
      privateKeyFile = config.sops.secrets."wireguard/private".path;

      peers = [
        {
          # Public key of the server (not a file path).
          publicKey = "zsHRKnTjUwQZqOdO0OhkJ9qdztLPjFoS7fMbjnvW71w=";

          # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
          # For a server peer this should be the whole subnet.
          allowedIPs = [
            "10.66.66.2/32"
            "fd42:42:42::2/128"
          ];

          presharedKeyFile = config.sops.secrets."wireguard/peer/test1".path;
          name = "test1";

          # Send keepalives every 25 seconds. Important to keep NAT tables alive.
          persistentKeepalive = 25;
        }
        {
          # Public key of the server (not a file path).
          publicKey = "2yqKN0Uvapedp1SQEPwmzeVXTcb0yWhK5rB1IqGUUVY=";

          # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
          # For a server peer this should be the whole subnet.
          allowedIPs = [
            "10.66.66.4/32"
            "fd42:42:42::4/128"
          ];

          presharedKeyFile = config.sops.secrets."wireguard/peer/ks273fb".path;
          name = "ks273fb";

          # Send keepalives every 25 seconds. Important to keep NAT tables alive.
          persistentKeepalive = 25;
        }
        {
          # Public key of the server (not a file path).
          publicKey = "2yqKN0Uvapedp1SQEPwmzeVXTcb0yWhK5rB1IqGUUVY=";

          # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
          # For a server peer this should be the whole subnet.
          allowedIPs = [
            "10.66.66.10/32"
            "fd42:42:42::10/128"
          ];

          presharedKeyFile = config.sops.secrets."wireguard/peer/giusi".path;
          name = "giusi";

          # Send keepalives every 25 seconds. Important to keep NAT tables alive.
          persistentKeepalive = 25;
        }
      ];
    };
  };

  /* systemd = {
    network = {
      config = {
        networkConfig = {
          IPv4Forwarding = true;
          IPv6Forwarding = true;
        };
      };
    };
  }; */
}
