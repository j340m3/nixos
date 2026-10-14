{ config, lib, pkgs, ... }:
let
  wg = builtins.fromJSON (builtins.readFile ../global/wireguard-peers.json);
  secretsFile = ../secrets/services/wireguard/secrets.yaml;
  peerSecret = p: "wireguard/peer/${p.name}";
in
{
  networking.nat.enable = true;
  # Hosts with `net.ifnames=0` expose their uplink as eth0 (jessie); the Ionos
  # VPS hosts use ens6. Override per host where needed.
  networking.nat.externalInterface = lib.mkDefault "eth0";
  networking.nat.internalInterfaces = [
    "wg0"
    "nebula.mesh"
  ];
  networking.nat.enableIPv6 = true;
  # Route traffic bound for the Nebula mesh (10.0.0.0/24) out nebula.mesh,
  # masqueraded to this host's own mesh IP. The nat module marks packets arriving
  # on the internal interfaces (wg0, nebula.mesh) with mark 1 in nixos-nat-pre,
  # but only masquerades them out externalInterface; matching that mark here adds
  # the nebula.mesh path. Using the mark (not a source range) covers every
  # routed source behind a wg peer, including a peer's LAN such as the FRITZ
  # 192.168.178.0/24. `-i` cannot be used in POSTROUTING, hence the mark. The
  # nixos-nat-post / nixos-filter-forward chains are flushed and rebuilt on every
  # firewall start, so this stays idempotent. (iptables backend; incompatible
  # with the nftables nat module.)
  networking.nat.extraCommands = ''
    iptables -w -t nat -A nixos-nat-post -m mark --mark 1 -o nebula.mesh -j MASQUERADE
    iptables -w -t filter -A nixos-filter-forward -i wg0 -o nebula.mesh -j ACCEPT
  '';
  networking.firewall.allowedUDPPorts = [ wg.server.listen_port ];

  sops.secrets = {
    "wireguard/private" = {
      sopsFile = secretsFile;
    };
  } // builtins.listToAttrs (map (p: {
    name = peerSecret p;
    value = { sopsFile = secretsFile; };
  }) wg.peers);

  # Enable Wireguard
  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {

      listenPort = wg.server.listen_port;
      # Determines the IP address and subnet of the client's end of the tunnel interface.
      ips = wg.server.address;

      # Path to the private key file.
      #
      # Note: The private key can also be included inline via the privateKey option,
      # but this makes the private key world-readable; thus, using privateKeyFile is
      # recommended.
      privateKeyFile = config.sops.secrets."wireguard/private".path;

      peers = map (p: {
        # Public key of the server (not a file path).
        publicKey = p.public_key;

        # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
        # For a server peer this should be the whole subnet.
        allowedIPs = p.allowed_ips;

        presharedKeyFile = config.sops.secrets."${peerSecret p}".path;
        name = p.name;

        # Send keepalives every 25 seconds. Important to keep NAT tables alive.
        persistentKeepalive = 25;
      }) wg.peers;
    };
  };

  /*
    systemd = {
      network = {
        config = {
          networkConfig = {
            IPv4Forwarding = true;
            IPv6Forwarding = true;
          };
        };
      };
    };
  */
}
