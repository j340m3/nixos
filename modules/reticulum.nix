{
  config,
  lib,
  pkgs,
  constants,
  ...
}:
let
  cfg = config.services.reticulum;
  host = config.networking.hostName;
  isPublic = lib.elem host constants.reticulum.publicHosts;
  isVps = lib.elem host constants.reticulum.vpsHosts;
  autoInterface = !isVps;
  lxmf = isPublic;

  rnspython = pkgs.python3.withPackages (
    ps: with ps; [
      rns
      lxmf
    ]
  );
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
      "  message_storage_limit = 100"
      "  propagation_message_max_accepted_size = 512"
      "  propagation_sync_max_accepted_size = 1024"
      "  auth_required = no"
      ""
      "[lxmf]"
      "  display_name = ${host}"
      "  announce_at_start = yes"
      "  announce_interval = 360"
      "  delivery_transfer_max_accepted_size = 1"
    ]
    + "\n";

  sshHosts =
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (h: v: "${h}-rns ${v.nix}") constants.reticulum.identities
    )
    + "\n";

  allowedIdentities = lib.concatMapStringsSep " " (
    h: "-a ${constants.reticulum.identities.${h}.hash}"
  ) (lib.attrNames constants.reticulum.identities);

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
    for arg in "$@"; do
      case "$arg" in
        *-rns)
          rns_host="$arg"
          break
          ;;
      esac
    done

    dest=
    if [ -n "$rns_host" ] && [ -r "$hosts_file" ]; then
      while read -r name hash; do
        if [ "$name" = "$rns_host" ]; then
          dest="$hash"
          break
        fi
      done < "$hosts_file"
    fi

    if [ -z "$dest" ]; then
      exec "$real_ssh" "$@"
    fi

    if [ "''${1:-}" = "-O" ] && [ "''${2:-}" = "check" ]; then
      exit 1
    fi

    if [ ! -r "$identity" ]; then
      echo "ssh-rns: missing $identity" >&2
      exit 1
    fi

    printf 'started\n'
    exec "$rnsh" --rnsconfig ${stateDir} -i "$identity" "$dest"
    EOF
        chmod +x "$out/bin/ssh"
  '';
in
{
  options.services.reticulum = {
    enable = lib.mkEnableOption "Reticulum";
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
      sopsFile = ../secrets/hosts/${host}/reticulum.yaml;
      owner = "root";
      group = "root";
      mode = "0400";
    };

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
        RuntimeDirectoryMode = "0700";
      };
      script = ''
        ${pkgs.coreutils}/bin/tr '_-' '/+' < ${
          config.sops.secrets."reticulum/identity".path
        } | ${pkgs.coreutils}/bin/base64 -d > /run/reticulum/identity
        chmod 0400 /run/reticulum/identity
      '';
    };

    systemd.services.reticulum = {
      description = "Reticulum network stack";
      after = [ "reticulum-identity.service" ];
      requires = [ "reticulum-identity.service" ];
      script = ''
        ${rnspython}/bin/rnsd --config ${stateDir} --service --verbose
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
        Restart = "always";
        RestartSec = "3s";
        LimitNOFILE = 1024;
      };
      script = ''
        exec ${rnsh}/bin/rnsh --rnsconfig ${stateDir} -l -C -i /run/reticulum/identity \
          ${allowedIdentities} \
          -- ${config.nix.package}/bin/nix-daemon --stdio
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
}
