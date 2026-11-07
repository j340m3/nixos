{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
in
{
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

      rnspython = pkgs.python3.withPackages (ps: [ ps.rns ] ++ lib.optional lxmf ps.lxmf);
      rnsPatched = pkgs.runCommand "rns-rnsh-streaming" { } ''
        mkdir -p "$out"
        cp -r ${pkgs.python3Packages.rns}/${pkgs.python3.sitePackages}/RNS "$out/RNS"
        substituteInPlace "$out/RNS/Utilities/rnsh/initiator.py" \
          --replace-fail \
            'data_buffer = bytearray(sys.stdin.buffer.read()) if not os.isatty(sys.stdin.fileno()) else bytearray()' \
            'data_buffer = bytearray()'
      '';
      rnsh = pkgs.writeShellScriptBin "rnsh" ''
        export PYTHONPATH=${rnsPatched}''${PYTHONPATH:+:$PYTHONPATH}
        exec ${rnspython}/bin/rnsh "$@"
      '';
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

      configLines = [
        "[reticulum]"
        "  enable_transport = ${bool isPublic}"
        "  share_instance = yes"
        "  shared_instance_port = 37428"
        "  instance_control_port = 37429"
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

      sshHosts =
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (h: v: "${h}-rns ${v.nix}") constants.reticulum.identities
        )
        # woody's SEPARATE ledger/listener identity: borg dialling
        # borg@woody-borg-rns:repo hits the backup bridge, not the nix daemon.
        + "\nwoody-borg-rns ${constants.reticulum.identities.woody.borg}"
        + "\n";

      allowedIdentities = lib.concatMapStringsSep " " (
        h: "-a ${constants.reticulum.identities.${h}.hash}"
      ) (lib.attrNames constants.reticulum.identities);

      allowBorgIdentities = lib.concatMapStringsSep " " (h: "-a ${h}") cfg.rnshBorg.allowIdentities;

      sshShim = pkgs.runCommand "openssh-rns-shim" { } ''
            mkdir -p "$out/bin"
            for bin in ${pkgs.openssh}/bin/*; do
              ln -s "$bin" "$out/bin/$(${pkgs.coreutils}/bin/basename "$bin")"
            done
            rm "$out/bin/ssh"
            cat > "$out/bin/ssh" <<'EOF'
        #!${pkgs.runtimeShell}
        set -euo pipefail

        real_ssh=${pkgs.openssh}/bin/ssh
        rnsh=${rnsh}/bin/rnsh
        identity=/run/reticulum/identity
        hosts_file=/etc/reticulum/ssh-hosts

        rns_host=
        host_pos=0
        pos=0
        for arg in "$@"; do
          pos=$((pos + 1))
          case "$arg" in
            *-rns*)
              rns_host="$arg"
              host_pos=$pos
              break
              ;;
          esac
        done

        dest=
        if [ -n "$rns_host" ] && [ -r "$hosts_file" ]; then
          # repo strings look like user@host:path — match on the host part
          # ("borg@woody-borg-rns:pricklepants" → "woody-borg-rns").
          name="''${rns_host%%:*}"
          name="''${name##*@}"
          while read -r hname hash; do
            if [ "$hname" = "$name" ]; then
              dest="$hash"
              break
            fi
          done < "$hosts_file"
        fi

        if [ -z "$dest" ]; then
          exec "$real_ssh" "$@"
        fi

        is_check=0
        previous=
        for arg in "$@"; do
          if [ "$previous" = "-O" ] && [ "$arg" = "check" ]; then
            is_check=1
            break
          fi
          previous="$arg"
        done
        if [ "$is_check" = 1 ]; then
          exit 1
        fi

        if [ ! -r "$identity" ]; then
          echo "ssh-rns: missing $identity" >&2
          exit 1
        fi

        # nix prepends LocalCommand="echo started" (libstore/ssh.cc) and expects
        # that marker back on stdout. Other speakers of this shim (borg, plain
        # ssh) speak the bare protocol and must NOT see it: only a remote
        # COMMAND after the host arg means "nix is talking".
        remote_command=0
        value_pending=0
        for arg in "''${@:$((host_pos + 1))}"; do
          if [ "$value_pending" = 1 ]; then
            value_pending=0
            continue
          fi
          case "$arg" in
            --)
              remote_command=1
              break
              ;;
            -o|-i|-l|-p|-c|-m|-L|-R|-D|-S|-F|-b|-E|-O|-J|-w|-G|-I)
              value_pending=1
              ;;
            -*) ;;
            *)
              remote_command=1
              break
              ;;
          esac
        done

        master=0
        session=0
        for arg in "$@"; do
          case "$arg" in
            -M*) master=1 ;;
            -S*) session=1 ;;
          esac
        done
        if [ "$master" = 1 ] || { [ "$session" = 0 ] && [ "$remote_command" = 1 ]; }; then
          printf 'started\n'
        fi
        exec "$rnsh" --rnsconfig ${stateDir} -i "$identity" "$dest"
        EOF
            chmod +x "$out/bin/ssh"
      '';
    in
    {
      options.services.reticulum = {
        enable = lib.mkEnableOption "Reticulum";

        # Non-root rnsh listeners need to read the identity and a minimal
        # RNS config view; group "reticulum" grants exactly that.
        identityReaders = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Users added to the `reticulum` group. Members can read the decoded
            fleet identity (/run/reticulum) and the shared-instance config
            view (/var/lib/reticulum-share) — everything a non-root rnsh
            listener needs. No write access anywhere.
          '';
        };

        rnshBorg = {
          enable = lib.mkEnableOption ''
            a second rnsh listener (separate identity, sops key
            `reticulum/borg_identity`) running `borg serve` as the borg user
            instead of exposing the root nix daemon to backup traffic
          '';

          repoPath = lib.mkOption {
            type = lib.types.path;
            default = "/var/lib/borgbackup";
            # mirrors the sshd accept side: clients cannot escape this tree
            description = "Directory the borg listener is restricted to.";
          };

          allowIdentities = lib.mkOption {
            type = lib.types.listOf (lib.types.strMatching "[0-9a-f]{32}");
            default = [ ];
            description = "RNS identity hashes permitted as rnsh-borg clients.";
          };
        };
      };

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
        users.groups.reticulum = { };
        users.users = lib.listToAttrs (
          map (u: lib.nameValuePair u { extraGroups = [ "reticulum" ]; })
          (lib.unique (cfg.identityReaders ++ lib.optionals cfg.rnshBorg.enable [ "borg" ]))
        );

        environment.etc."reticulum/config".text = configText;
        environment.etc."reticulum/ssh-hosts".text = sshHosts;
        environment.etc."lxmd/config" = lib.mkIf lxmf {
          text = lxmfConfig;
        };

        environment.systemPackages = [ sshShim ];
        programs.ssh.package = lib.mkDefault sshShim;

        systemd.services.reticulum-identity = {
          description = "Decode the Reticulum identity";
          wantedBy = [ "multi-user.target" ];
          before = [
            "reticulum.service"
            "rnsh-nix.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            RuntimeDirectory = "reticulum";
            RuntimeDirectoryMode = "0750";
            # group-readable identity: non-root rnsh listeners (remotebuild,
            # borg) authenticate for the shared instance through group perms
            Group = "reticulum";
          };
          script = ''
            ${pkgs.coreutils}/bin/tr '_-' '/+' < ${
              config.sops.secrets."reticulum/identity".path
            } | ${pkgs.coreutils}/bin/base64 -d > /run/reticulum/identity
            chmod 0440 /run/reticulum/identity
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
            StateDirectory = "reticulum";
            StateDirectoryMode = "0700";
            ExecStartPre = "${pkgs.coreutils}/bin/ln -sfn /etc/reticulum/config ${stateDir}/config";
            Restart = "always";
            RestartSec = "3s";
          };
        };

        systemd.services.rnsh-nix = {
          description = "rnsh bridge for the Nix daemon";
          after = [
            "reticulum.service"
            "reticulum-identity.service"
          ];
          requires = [
            "reticulum.service"
            "reticulum-identity.service"
          ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            PartOf = [ "reticulum.service" ];
            Restart = "always";
            RestartSec = "3s";
            LimitNOFILE = 1024;
            # Downgraded from root: identity is the authorized_keys equivalent,
            # the remotebuild account is the factor between peer and daemon —
            # byte-for-byte the same chain as the nebula ssh-ng path.
            User = "remotebuild";
            Group = "remotebuild";
            # RNS wants a writable config dir in $HOME (remotebuild's is /var/empty)
            RuntimeDirectory = "rnsh-nix";
            Environment = "HOME=/run/rnsh-nix";
            # own writable rnsconfig: RNS creates storage/ here; the fleet
            # config is symlinked in by the root ExecStartPre below
            ExecStartPre = "+${
              pkgs.writeShellScript "rnsh-nix-rnsconfig" ''
                ${pkgs.coreutils}/bin/ln -sfn /etc/reticulum/config /run/rnsh-nix/config
              ''
            }";
          };
          script = ''
            expected=${constants.reticulum.identities.${host}.nix}
            actual=$(${rnspython}/bin/rnid --config /run/rnsh-nix -i /run/reticulum/identity -H rnsh 2>/dev/null | ${pkgs.gnugrep}/bin/grep 'rnsh destination' | ${pkgs.gnugrep}/bin/grep -oE '[0-9a-f]{32}' || true)
            if [ "$actual" != "$expected" ]; then
              echo "rnsh-nix: destination hash mismatch: expected $expected, got '$actual'" >&2
              exit 1
            fi
            exec ${rnsh}/bin/rnsh --rnsconfig /run/rnsh-nix -l -b 900 -C -i /run/reticulum/identity \
              ${allowedIdentities} \
              -- ${config.nix.package}/bin/nix-daemon --stdio
          '';
        };

        sops.secrets."reticulum/borg_identity" = lib.mkIf cfg.rnshBorg.enable {
          key = "borg_identity";
          sopsFile = ../../secrets/hosts/${host}/reticulum.yaml;
          owner = "root";
          group = "reticulum";
          mode = "0440";
          restartUnits = [ "rnsh-borg.service" ];
        };

        systemd.services.rnsh-borg = lib.mkIf cfg.rnshBorg.enable {
          description = "rnsh bridge for borg (append-only repos)";
          after = [
            "reticulum.service"
            "reticulum-identity.service"
          ];
          requires = [
            "reticulum.service"
            "reticulum-identity.service"
          ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            PartOf = [ "reticulum.service" ];
            Restart = "always";
            RestartSec = "3s";
            LimitNOFILE = 1024;
            User = "borg";
            Group = "borg";
            # clients read repo path "NAME" relative to the serving process CWD
            WorkingDirectory = "${cfg.rnshBorg.repoPath}";
            # borg's home is /var/empty (root-owned); RNS needs a writable HOME
            Environment = "HOME=/run/rnsh-borg";
            RuntimeDirectory = "rnsh-borg";
            # the bridge identity is borg-only: decode happens here as root
            ExecStartPre = "+${
              pkgs.writeShellScript "rnsh-borg-identity" ''
                ${pkgs.coreutils}/bin/tr '_-' '/+' < ${
                  config.sops.secrets."reticulum/borg_identity".path
                } | ${pkgs.coreutils}/bin/base64 -d > /run/reticulum/identity-borg
                # the + Exec runs root:root; the listener reads via group perms
                chown root:reticulum /run/reticulum/identity-borg
                chmod 0440 /run/reticulum/identity-borg
                ${pkgs.coreutils}/bin/ln -sfn /etc/reticulum/config /run/rnsh-borg/config
              ''
            }";
          };
          script = ''
            expected=${constants.reticulum.identities.${host}.borg}
            actual=$(${rnspython}/bin/rnid --config /run/rnsh-borg -i /run/reticulum/identity-borg -H rnsh 2>/dev/null | ${pkgs.gnugrep}/bin/grep 'rnsh destination' | ${pkgs.gnugrep}/bin/grep -oE '[0-9a-f]{32}' || true)
            if [ "$actual" != "$expected" ]; then
              echo "rnsh-borg: destination hash mismatch: expected $expected, got '$actual'" >&2
              exit 1
            fi
            exec ${rnsh}/bin/rnsh --rnsconfig /run/rnsh-borg -l -b 900 -C -i /run/reticulum/identity-borg \
              ${allowBorgIdentities} \
              -- ${config.services.borgbackup.package}/bin/borg serve --append-only --restrict-to-path ${cfg.rnshBorg.repoPath}
          '';
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
        };

        networking.firewall.allowedTCPPorts = lib.mkIf isPublic [ constants.reticulum.port ];
        networking.firewall.allowedUDPPorts = lib.mkIf autoInterface [
          29716
          42671
        ];
      };
    };
}
