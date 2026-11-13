# rnsh-as-ssh transport: a shim that replaces openssh's `ssh` binary and
# dials `-rns`-suffixed hostnames over Reticulum (rnsh) instead of tcp.
# Non-rns hostnames fall through to real ssh, so this shadows ssh
# fleet-wide without changing any other ssh behaviour. Consumers: borg
# repos (`borg@<host>-rns:repo`), nix distributed builds
# (`ssh-ng://<host>-rns`), and the borg bridge identity ledger below.
{ inputs, ... }:
let
  constants = import ../global/_constants.nix;
in
{
  flake.modules.nixos.rnsh-ssh =
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
      stateDir = "/var/lib/reticulum";

      rn = inputs.self.lib.rnsh {
        inherit pkgs;
        lxmf = isPublic;
      };
      inherit (rn) rnsh;

      sshHosts =
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (h: v: "${h}-rns ${v.nix}") constants.reticulum.identities
        )
        # woody's SEPARATE ledger/listener identity: borg dialling
        # borg@woody-borg-rns:repo hits the backup bridge, not the nix daemon.
        + "\nwoody-borg-rns ${constants.reticulum.identities.woody.borg}"
        + "\n";

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
              # Bare positional without '--': NOT a nix-style remote command
              # (nix always sends '--' before its command; borg sends args
              # like "serve" directly). Such speakers need the bare protocol,
              # so stop scanning without setting the marker.
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
      config = lib.mkIf cfg.enable {
        environment.etc."reticulum/ssh-hosts".text = sshHosts;

        environment.systemPackages = [ sshShim ];
        programs.ssh.package = lib.mkDefault sshShim;
      };
    };
}
