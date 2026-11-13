{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
in
{
  # Reticulum transport core: the shared-instance daemon (rnsd), the
  # rendered RNS config (audit F2 template + rpc_key render), the identity
  # decode unit, the public/fleet listeners, and lxmf on public hosts.
  # Companions, one feature each:
  #   modules/nix/reticulum-opts.nix   option tree carrier (mesh-ports pattern)
  #   modules/system/rnsh-ssh.nix      ssh shim: -rns hostnames dial rnsh
  #   modules/system/rnsh-nix.nix      nix-daemon bridge listener
  #   modules/services/rnsh-borg.nix   borg serve bridge listener
  flake.modules.nixos.reticulum =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.reticulum;
      host = config.networking.hostName;
      isPublic = lib.elem host constants.reticulum.publicHosts;
      isVps = lib.elem host constants.reticulum.vpsHosts;
      autoInterface = !isVps;
      lxmf = isPublic;

      rn = inputs.self.lib.rnsh { inherit pkgs lxmf; };
      inherit (rn) rnspython;
      stateDir = "/var/lib/reticulum";
      lxmfStateDir = "/var/lib/lxmd";

      bool = b: if b then "yes" else "no";
      publicV4 =
        h:
        lib.head (
          map (e: lib.head (lib.splitString ":" e)) (
            lib.filter (e: !(lib.hasPrefix "[" e)) constants.host.${h}.endpoints
          )
        );

      publicListener = [
        "  [[Public Backbone]]"
        "    type = BackboneInterface"
        "    enabled = yes"
        "    listen_ip = 0.0.0.0"
        "    port = ${toString constants.reticulum.port}"
        "    mode = gateway"
        "    discoverable = yes"
        "    discovery_name = ${host}"
        "    reachable_on = ${publicV4 host}"
        "    announce_interval = 720"
        "    discovery_stamp_value = 20"
        "    announce_rate_target = 3600"
        "    announce_rate_penalty = 3600"
        "    announce_rate_grace = 6"
      ];

      peerInterface = h: [
        "  [[Fleet ${h}]]"
        "    type = BackboneInterface"
        "    enabled = yes"
        "    remote = ${publicV4 h}"
        "    port = ${toString constants.reticulum.port}"
      ];

      externalInterface = peer: [
        "  [[External ${peer.name}]]"
        "    type = BackboneInterface"
        "    enabled = yes"
        "    remote = ${peer.host}"
        "    port = ${toString peer.port}"
      ];

      autoInterfaceLines = [
        "  [[AutoInterface]]"
        "    type = AutoInterface"
        "    enabled = yes"
      ];

      # Audit F2: the local RPC auth key for the shared-instance control port
      # is a random per-host secret in sops (reticulum/rpc_key), NOT the old
      # hostname-derived sha256 hash — any local process could compute that
      # from the hostname alone and gain control-plane admin over the shared
      # rnsd (the local channels are abstract AF_UNIX sockets with no
      # filesystem permissions, so the key is the ONLY gate). Without a key,
      # non-root listeners die at the first LINKIDENTIFY (is_blackholed() ->
      # AuthenticationError). /etc/reticulum/config carries an @rpcKey@
      # placeholder; reticulum-identity.service substitutes the sops value
      # into /run/reticulum/config at boot, so no store path ever sees the
      # real key.

      configLines = [
        "[reticulum]"
        "  enable_transport = ${bool isPublic}"
        "  share_instance = yes"
        "  shared_instance_port = 37428"
        "  instance_control_port = 37429"
        "  rpc_key = @rpcKey@"
        "  panic_on_interface_error = no"
        "  discover_interfaces = ${bool isPublic}"
      ]
      ++ lib.optionals isPublic [
        "  required_discovery_value = 16"
        "  autoconnect_discovered_interfaces = 0"
        "  respond_to_probes = yes"
      ]
      ++ [
        ""
        "[logging]"
        "  loglevel = 4"
        ""
        "[interfaces]"
      ]
      ++ lib.optionals isPublic (
        publicListener
        ++ lib.concatMap peerInterface (lib.filter (h: h != host) constants.reticulum.publicHosts)
        ++ lib.concatMap externalInterface constants.reticulum.externalPeers
      )
      ++ lib.optionals (!isPublic) (lib.concatMap peerInterface constants.reticulum.publicHosts)
      ++ lib.optionals autoInterface autoInterfaceLines;

      configText = lib.concatStringsSep "\n" configLines + "\n";

      lxmfConfig =
        lib.concatStringsSep "\n" [
          "[propagation]"
          "  enable_node = yes"
          "  node_name = ${host}"
          "  announce_interval = 360"
          "  announce_at_start = yes"
          "  autopeer = yes"
          "  autopeer_maxdepth = 4"
          "  propagation_stamp_cost_target = 16"
          "  propagation_stamp_cost_flexibility = 3"
          "  peering_cost = 18"
          "  message_storage_limit = 100"
          "  propagation_message_max_accepted_size = 512"
          "  propagation_sync_max_accepted_size = 1024"
          "  auth_required = no"
          ""
          "[lxmf]"
          "  display_name = ${host}"
          "  stamp_cost = 12"
          "  announce_at_start = yes"
          "  announce_interval = 360"
          "  delivery_transfer_max_accepted_size = 1"
        ]
        + "\n";
    in
    {
      config = lib.mkIf cfg.enable {
        nixpkgs.config.allowUnfreePredicate = lib.mkDefault (
          pkg:
          builtins.elem (lib.getName pkg) [
            "rns"
            "lxmf"
          ]
        );

        sops.secrets."reticulum/identity" = {
          key = "identity";
          sopsFile = ../../secrets/hosts/${host}/reticulum.yaml;
          owner = "root";
          group = "root";
          mode = "0400";
        };

        # Non-root rnsh listeners: each process gets its OWN writable rnsconfig
        # dir (RNS always creates storage/ there, even as a shared-instance
        # client) with the fleet config symlinked in; group "reticulum" grants
        # the 0440 identity reads. /var/lib/reticulum itself stays 0700 root.
        # Group split (audit F3): group `reticulum` = fleet identity +
        # rendered config readers (the rnsh-nix side); group `rnsh-borg`
        # (declared in modules/services/rnsh-borg.nix) = the borg bridge
        # identity + its config copy only. A compromised remotebuild can no
        # longer impersonate the borg bridge, and a compromised borg cannot
        # grab the fleet (nix-bridge) identity.
        users.groups = {
          reticulum = { };
          rnsd = { };
        };
        users.users = lib.mkMerge [
          (lib.listToAttrs (
            map (u: lib.nameValuePair u { extraGroups = [ "reticulum" ]; })
              cfg.identityReaders
          ))
          {
            # rnsd runs unprivileged (audit F6): it parses untrusted wire
            # traffic on port 4242 (unprivileged), so it needs no
            # capabilities. Group reticulum grants the rendered config read.
            rnsd = {
              isSystemUser = true;
              group = "rnsd";
              extraGroups = [ "reticulum" ];
            };
          }
        ];

        # Static RNS config TEMPLATE (audit F2): holds the @rpcKey@
        # placeholder only. reticulum-identity.service substitutes the sops
        # value into /run/reticulum/config (root:reticulum 0440); rnsd and
        # every listener read the rendered copy, never this file.
        environment.etc."reticulum/config" = {
          text = configText;
          mode = "0644";
        };
        environment.etc."lxmd/config" = lib.mkIf lxmf {
          text = lxmfConfig;
        };

        systemd.services.reticulum-identity = {
          description = "Decode the Reticulum identity and render the RNS config";
          wantedBy = [ "multi-user.target" ];
          before = [
            "reticulum.service"
            "rnsh-nix.service"
          ] ++ lib.optionals cfg.rnshBorg.enable [ "rnsh-borg.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            RuntimeDirectory = [ "reticulum" ] ++ lib.optionals cfg.rnshBorg.enable [ "reticulum-borg" ];
            RuntimeDirectoryMode = "0750";
            # group-readable identity: non-root rnsh listeners (remotebuild,
            # borg) authenticate for the shared instance through group perms
            Group = "reticulum";
            # audit F6: root oneshot, but minimal
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ReadWritePaths =
              [ "/run/reticulum" ]
              ++ lib.optionals cfg.rnshBorg.enable [ "/run/reticulum-borg" ];
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectKernelLogs = true;
            ProtectClock = true;
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            CapabilityBoundingSet = "";
            SystemCallArchitectures = "native";
          };
          script = ''
            ${pkgs.coreutils}/bin/tr '_-' '/+' < ${
              config.sops.secrets."reticulum/identity".path
            } | ${pkgs.coreutils}/bin/base64 -d > /run/reticulum/identity
            chmod 0440 /run/reticulum/identity
            # Render the RNS config (audit F2): substitute the rpc_key from
            # sops into the static /etc/reticulum/config template.
            ${pkgs.gnused}/bin/sed "s|@rpcKey@|$(cat ${
              config.sops.secrets."reticulum/rpc_key".path
            })|" /etc/reticulum/config > /run/reticulum/config
            chown root:reticulum /run/reticulum/config
            chmod 0440 /run/reticulum/config
          '' + lib.optionalString cfg.rnshBorg.enable ''
            # borg's own config copy (audit F3): the borg user is not in
            # group reticulum, so it gets this copy (same content) with
            # rnsh-borg-only permissions.
            chown root:borg /run/reticulum-borg
            chmod 0750 /run/reticulum-borg
            cp /run/reticulum/config /run/reticulum-borg/config
            chown root:borg /run/reticulum-borg/config
            chmod 0440 /run/reticulum-borg/config
          '';
        };

        systemd.services.reticulum = {
          description = "Reticulum network stack";
          after = [ "reticulum-identity.service" ];
          requires = [ "reticulum-identity.service" ];
          script = ''
            exec ${rnspython}/bin/rnsd --config ${stateDir} --service --verbose
          '';
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            # audit F6: run the untrusted-traffic parser as a system user
            User = "rnsd";
            Group = "rnsd";
            StateDirectory = "reticulum";
            StateDirectoryMode = "0700";
            # legacy /var/lib/reticulum was root-owned; fix ownership each
            # start (runs before the config symlink is created)
            ExecStartPre = [
              "+${pkgs.coreutils}/bin/chown -R rnsd:rnsd ${stateDir}"
              "${pkgs.coreutils}/bin/ln -sfn /run/reticulum/config ${stateDir}/config"
            ];
            ReadWritePaths = [ "${stateDir}" ];
            Restart = "always";
            RestartSec = "3s";
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectKernelLogs = true;
            ProtectControlGroups = true;
            ProtectClock = true;
            ProtectHostname = true;
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            LockPersonality = true;
            RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
            CapabilityBoundingSet = "";
            SystemCallArchitectures = "native";
          };
          # rnsd reads its config once at start; without a trigger a config
          # change (rpc_key, interfaces) silently leaves rnsd on the old
          # file -> rpc authkey mismatch -> initiator-side "Protocol error"
          restartTriggers = [
            (pkgs.writeText "reticulum-config-restart-trigger" configText)
          ];
        };

        # Audit F2: random per-host control-plane key. Rotation re-renders
        # the config and restarts the daemon and its listeners.
        sops.secrets."reticulum/rpc_key" = {
          key = "rpc_key";
          sopsFile = ../../secrets/hosts/${host}/reticulum.yaml;
          owner = "root";
          group = "root";
          mode = "0400";
          restartUnits = [
            "reticulum-identity.service"
            "reticulum.service"
            "rnsh-nix.service"
          ] ++ lib.optionals cfg.rnshBorg.enable [ "rnsh-borg.service" ];
        };

        systemd.services.lxmf = lib.mkIf lxmf {
          description = "LXMF propagation node";
          after = [ "reticulum.service" ];
          requires = [ "reticulum.service" ];
          script = ''
            ${rnspython}/bin/lxmd --config ${lxmfStateDir} --rnsconfig ${stateDir} --service --verbose
          '';
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            PartOf = [ "reticulum.service" ];
            StateDirectory = "lxmd";
            StateDirectoryMode = "0700";
            ExecStartPre = "${pkgs.coreutils}/bin/ln -sfn /etc/lxmd/config ${lxmfStateDir}/config";
            Restart = "always";
            RestartSec = "3s";
            TimeoutStopSec = "10s";
          };
          restartTriggers = [
            (pkgs.writeText "lxmf-config-restart-trigger" lxmfConfig)
          ];
        };

        networking.firewall.allowedTCPPorts = lib.mkIf isPublic [ constants.reticulum.port ];
        networking.firewall.allowedUDPPorts = lib.mkIf autoInterface [
          29716
          42671
        ];
      };
    };
}
