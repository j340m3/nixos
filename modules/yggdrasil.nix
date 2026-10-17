{
  config,
  lib,
  constants,
  ...
}:
let
  hostName = config.networking.hostName;
  # roster entries are optional: lenny/rex/slinky have no constants.host
  # entry yet — every constants.host lookup below is guardedly optional
  isLighthouse = builtins.elem hostName constants.lighthouses;
  # lighthouses' public endpoints minus the trailing ":4242" (nebula udp),
  # reused as ygg tls peer hosts
  endpointHost =
    ep: lib.concatStringsSep ":" (lib.dropEnd 1 (lib.splitString ":" ep));
  peerLighthouses = builtins.filter (h: h != hostName) constants.lighthouses;
  # one tls URI per *endpoint* of each peer lighthouse (the nebula ":4242"
  # suffix is stripped, replaced by the ygg port) — ygg tries them all
  yggPeers = builtins.concatMap
    (h: map (ep: "tls://${endpointHost ep}:${toString constants.yggPort}") (constants.host.${h}.endpoints or [ ]))
    peerLighthouses;
  fleetKeys = builtins.filter (k: k != null) (
    map (n: constants.host.${n}.yggPub or null) (builtins.attrNames constants.host)
  );
in
{
  services.yggdrasil = {
    enable = true;
    openMulticastPort = true;
    persistentKeys = true;
    settings = {
      "Peers" = lib.mkIf (!isLighthouse && fleetKeys != [ ]) yggPeers;
      "Listen" = lib.mkIf (isLighthouse && fleetKeys != [ ]) [ "tcp://0.0.0.0:${toString constants.yggPort}" ];
      "AllowedPublicKeys" = fleetKeys;
      "IfName" = "ygg";
      "IfMTU" = 65535;
    };
  };

  # lighthouses accept WAN peerings; members only ever dial out
  networking.firewall.allowedTCPPorts = lib.mkIf isLighthouse [ constants.yggPort ];
}
