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
      ygg = "200:7b7a:984c:6206:75a4:6cb4:2a89:4275";
      yggPub = "c242b3d9cefcc52dc9a5eabb5ec5698728d4cc27e5c776c670cfc3799ae372ac";
    };
    buzz = {
      ip = "10.0.0.5";
      endpoints = [
        "194.164.54.40:4242"
        "[2a01:239:27f:fd00::1]:4242"
      ];
      ygg = null;
      yggPub = null;
    };
    woody = {
      ip = "10.0.0.3";
      ygg = "200:c21a:8e2b:4ccb:834e:e195:f938:d1e7";
      yggPub = "9ef2b8ea599a3e588f350363970c186aa5ba5d641fdf0d01f5f6cb4388202ae3";
    };
    mrpotatohead = {
      ip = "10.0.0.6";
      endpoints = [
        "85.214.10.114:4242"
        "[2a01:239:4ac:7300::1]:4242"
      ];
      ygg = null;
      yggPub = null;
    };
    jessie = {
      ip = "10.0.0.7";
      endpoints = [
        "217.154.211.186:4242"
        "[2a01:239:396:fd00::1]:4242"
      ];
      ygg = null;
      yggPub = null;
    };
    # mesh members without a verified nebula address yet — ygg harvest (T8)
    # must cover them, or AllowedPublicKeys pins them out of the overlay
    lenny = { ygg = null; yggPub = null; };
    rex = { ygg = null; yggPub = null; };
  };

  # The DNS/relay backbone (names into the roster above); pricklepants
  # serves_mesh DNS (serve_dns), the other three do not. Endpoints are
  # leased public addresses (DHCP/DHCPv6, ~20min renewals, stable in
  # practice) — re-enter the roster from `ip a` when a provider rotates one.
  lighthouses = [ "pricklepants" "buzz" "jessie" "mrpotatohead" ];

  sshPort = 42069;

  # Yggdrasil backup overlay facts: address + node box pubkey harvested via
  # `yggdrasilctl getSelf` per host (after first boot with persistentKeys).
  # null until harvested; consumers are null-guarded. Addresses and box
  # pubkeys are public facts, not secrets. AllowedPublicKeys pinning happens
  # in modules/yggdrasil.nix from these values.
  yggPort = 1337;

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
in
{
  nebula.cidr = "10.0.0.0/24";
  # The lighthouse that runs the mesh DNS (must have lighthouse.serve_dns).
  nebula.dns = "pricklepants";
  # The mesh udp listen/peer port (suffix of every endpoint above).
  nebula.port = 4242;

  inherit host lighthouses sshPort yggPort;

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
