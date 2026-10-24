let
  # Single mesh roster: host.<name>.ip = nebula address, endpoints = public
  # udp endpoints (lighthouses only), lighthouses = the relay/DNS backbone.
  # Certs remain the actual identity; only verified addresses go here
  # (lenny/rex/slinky pending - their ip.nebula lives in secrets/shared.yaml).
  host = {
    pricklepants = {
      ip = "10.0.0.1";
      endpoints = [
        "194.164.125.154:4242"
        "[2a00:da00:f43a:8800::1]:4242"
      ];
    };
    buzz = {
      ip = "10.0.0.5";
      endpoints = [
        "194.164.54.40:4242"
        "[2a01:239:27f:fd00::1]:4242"
      ];
    };
    woody = {
      ip = "10.0.0.3";
    };
    mrpotatohead = {
      ip = "10.0.0.6";
      endpoints = [
        "85.214.10.114:4242"
        "[2a01:239:4ac:7300::1]:4242"
      ];
    };
    jessie = {
      ip = "10.0.0.7";
      endpoints = [
        "217.154.211.186:4242"
        "[2a01:239:396:fd00::1]:4242"
      ];
    };
    # mesh members without a verified nebula address yet
    lenny = {
    };
    rex = {
    };
    slinky = {
    };
  };

  # The DNS/relay backbone (names into the roster above). Endpoints are
  # leased public addresses (DHCP/DHCPv6, ~20min renewals, stable in
  # practice) — re-enter the roster from `ip a` when a provider rotates one.
  lighthouses = [
    "pricklepants"
    "buzz"
    "jessie"
    "mrpotatohead"
  ];

  sshPort = 42069;

  # Remote-build targets over the mesh (subset of `host`). A builder entry
  # enrolls a host as a build target; the accept side (remotebuild user,
  # trusted-users, authorizedKeys) is automatic for every mesh member
  # (modules/nebula.nix => modules/remote-builder.nix). Enrolling a host = its
  # ssh.pub in secrets/common/ssh/<h>/ (feeds knownHosts) and its root key in
  # modules/remote-builder.nix authorizedKeys. Opportunistic accelerators
  # only; absence means not attempted, unreachable falls back to local
  # builds.
  builders = [
    "pricklepants"
    "buzz"
    "mrpotatohead"
    "jessie"
    "woody"
  ];

  # Reticulum fleet overlay. Public transports are the VPS lighthouses plus
  # jessie; every other roster host is a client. External peers are the
  # public testnet (no shared secret).
  reticulum = {
    port = 4242;
    publicHosts = lighthouses;
    vpsHosts = [
      "pricklepants"
      "buzz"
      "mrpotatohead"
    ];
    externalPeers = [
      {
        name = "dismail";
        host = "rns.dismail.de";
        port = 7822;
      }
      {
        name = "fn";
        host = "202.61.243.41";
        port = 4965;
      }
      {
        name = "istanbul";
        host = "istanbul.reserve.network";
        port = 9034;
      }
      {
        name = "sydney";
        host = "sydney.reticulum.au";
        port = 4242;
      }
      {
        name = "sideband";
        host = "sideband.connect.reticulum.network";
        port = 7822;
      }
    ];
    # `hash` is the rnid identity hash (rnsh allowlist); `nix` is the base
    # rnsh destination hash used by the ssh shim (rnsh ignores -s here).
    identities = {
      pricklepants.hash = "dcdc9aeca3f90daa00f45654e2e38443";
      pricklepants.nix = "0efcb07069aec9c89763c549fa3ed0db";
      buzz.hash = "c2dea2b92488fe8284df38d9348d5770";
      buzz.nix = "5adf7ddc1a927af62cbfd22d1d8a393f";
      woody.hash = "f921a6b4ccb4477fbf27124bc724c30f";
      woody.nix = "252990ad10a5c148041aeac99fa2b54f";
      mrpotatohead.hash = "cbda20fffed88a8a403766c4eec84c2f";
      mrpotatohead.nix = "9cd41760be653f33273ebf976840ab96";
      jessie.hash = "43456921b522914308923c8b0791ed56";
      jessie.nix = "378e66d79ec052cfec8e857d8a538b26";
      lenny.hash = "5f1c4a9f0bee5248a2f8e3c6d905f8a9";
      lenny.nix = "a2cf800d80b8ec01b4331483e31f650e";
      rex.hash = "3bcd6766e5cf13df42cc49cece312dd3";
      rex.nix = "b8e3998d8822ea9d5739a7099e26d9c4";
      slinky.hash = "d4a8944c1e5dccf5166c2884142667bf";
      slinky.nix = "ec395a7d5d6b299b71889743602ad607";
    };
  };
in
{
  nebula.cidr = "10.0.0.0/24";
  # The mesh udp listen/peer port (suffix of every endpoint above).
  nebula.port = 4242;

  inherit
    host
    lighthouses
    reticulum
    sshPort
    ;

  # staticHostMap for nebula configs: all lighthouses except the host itself
  # (name -> ip + endpoints). Used by modules/nebula.nix and the two inline
  # lighthouse configs: constants.nebula.staticMap config.networking.hostName.
  nebula.staticMap =
    self:
    builtins.listToAttrs (
      map (h: {
        name = host.${h}.ip;
        value = host.${h}.endpoints;
      }) (builtins.filter (h: h != self) lighthouses)
    );

  buildHosts = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = {
        connect = host.${name}.ip;
        port = sshPort;
        user = "remotebuild";
        systems = [ "x86_64-linux" ];
        speedFactor = 1;
      };
    }) builders
  );
}
