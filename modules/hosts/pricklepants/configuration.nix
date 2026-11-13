# Host aspect (ADR 0014): the module list is assembled by lib.mkNixos
# (modules/nix/lib.nix) from flake.modules.nixos.pricklepants; the
# flake-parts.nix one-liner next to this file declares the host into the
# flake. inputs/constants close over the head args. Two-file host: the
# hardware scan result is inlined below — no host-local glue.
{ inputs, lib, ... }:

let
  constants = import ../../../modules/global/_constants.nix;
in
{
  flake.modules.nixos.pricklepants =
    {
      modulesPath,
      pkgs,
      lib,
      config,
      ...
    }:
    let
      rootPath = ../../../.;
    in
    {
      imports = [
        # Inlined from ./_hardware-configuration.nix.
        (modulesPath + "/profiles/qemu-guest.nix")
        (modulesPath + "/profiles/minimal.nix")
        (modulesPath + "/profiles/headless.nix")
        inputs.self.modules.nixos.vps-guest
        inputs.self.modules.nixos.minetest
        inputs.self.modules.nixos.vaultwarden
        inputs.self.modules.nixos.logging
        inputs.self.modules.nixos.acme
        inputs.self.modules.nixos.system-default
        inputs.self.modules.nixos.wireguard
        # nebula via the lighthouse flavor (roster-derived am_lighthouse); it
        # also brings the remote-build accept side
        inputs.self.modules.nixos.nebula-lighthouse
        # Key rotated 2026-10-19 after the priv was never published (backups failed
        # auth with /dev/null); rotate into woody's repos via the .pub file.
        #
        # Phase-1 RNS cutover: repo resolves through the binary-clean reticulum
        # bridge on woody; BORG_RSH stays for a one-line rollback to nebula.
        (inputs.self.lib.borgClientJob {
          name = "pricklepants";
          # Backup paths must track the vaultwarden module, not hardcode them:
          # the upstream module derives StateDirectory from system.stateVersion
          # ("bitwarden_rs" below 24.11, "vaultwarden" after), so a hardcoded
          # /var/lib/vaultwarden broke with a silent stat error on every run
          # (2026-11-13 'stat: No such file'). serviceConfig.StateDirectory is
          # where the module publishes the live name; backupDir is the sqlite
          # dump dir the daily backup-vaultwarden timer fills (a second,
          # sqlite-consistent copy).
          paths = [
            "/etc"
            "/var/lib/${config.systemd.services.vaultwarden.serviceConfig.StateDirectory}"
            (toString config.services.vaultwarden.backupDir)
          ];
          repo = "borg@woody-borg-rns:pricklepants";
          secretFile = ../../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
          tolerateRepoDrift = false;
          # Absolute path: the borgbackup module adds pkgs.openssh to the unit
          # PATH (path = [ package openssh ]), which shadows the -rns shim and
          # breaks name resolution for woody-borg-rns (2026-11-11). Pin the
          # shim explicitly; the shim drops -i/-p, key stays inert here and
          # keeps the one-line rollback to nebula working.
          borgRsh = "/run/current-system/sw/bin/ssh -i ${
            config.sops.secrets."borg/pricklepants".path
          } -p ${toString constants.sshPort}";
        })
      ];

      # Inlined from ./_hardware-configuration.nix (zero host-local glue, ADR 0014).
      boot.loader.grub.device = "/dev/vda";
      boot.initrd.availableKernelModules = [
        "ata_piix"
        "uhci_hcd"
        "xen_blkfront"
        "vmw_pvscsi"
      ];
      boot.initrd.kernelModules = [ "nvme" ];
      fileSystems."/" = {
        device = "/dev/vda1";
        fsType = "ext4";
      };
      swapDevices = [
        {
          device = "/dev/vda16";
          randomEncryption.enable = true;
        }
      ];

      nix.gc.dates = lib.mkForce "hourly";
      nix.gc.options = lib.mkForce "-d";
      boot.loader.grub.configurationLimit = 2;
      #system.autoUpgrade.dates = lib.mkForce "daily";

      environment.systemPackages = with pkgs; [
        #bc
        #ipcalc
        #curl
        #procps
        #lynis
        git
        #chkrootkit
        #nix-tree
      ];

      networking.hostName = "pricklepants";
      # Ionos uplink NIC is ens6 (not eth0), so the WireGuard NAT masquerade binds correctly.
      networking.nat.externalInterface = "ens6";
      # Kernel-level per-IP rate limit on public ssh (2026-11-12: wall-to-wall
      # brute force on ens6 kept rsyslogd at ~46% CPU for days and starved the
      # single-threaded rnsd during borg transfers). Inserted at the TOP of
      # nixos-fw: extraCommands renders after the blanket allowedTCPPorts
      # accept, so a plain -A drop for 42069 would never be reached. Nebula
      # traffic arrives on the nebula iface and is untouched. Legit clients
      # stay under 6 new connections/min per source IP; anything above is
      # refused with capped logging (nixos-fw-log-refuse).
      networking.firewall.extraCommands = ''
        iptables -w -I nixos-fw 1 -i ens6 -p tcp --dport 42069 -m conntrack --ctstate NEW -m hashlimit --hashlimit-upto 6/minute --hashlimit-burst 8 --hashlimit-mode srcip --hashlimit-name sshguard -j nixos-fw-accept
        iptables -w -I nixos-fw 2 -i ens6 -p tcp --dport 42069 -m conntrack --ctstate NEW -j nixos-fw-log-refuse
        ip6tables -w -I nixos-fw 1 -i ens6 -p tcp --dport 42069 -m conntrack --ctstate NEW -m hashlimit --hashlimit-upto 6/minute --hashlimit-burst 8 --hashlimit-mode srcip --hashlimit-name sshguard6 -j nixos-fw-accept
        ip6tables -w -I nixos-fw 2 -i ens6 -p tcp --dport 42069 -m conntrack --ctstate NEW -j nixos-fw-log-refuse
      '';
      #services.fail2ban.enable = true;
      services.openssh = {
        ports = [ 42069 ];
        enable = true;
        settings.PasswordAuthentication = false;
        settings.KbdInteractiveAuthentication = lib.mkDefault false;
        settings.PermitRootLogin = "no";
        settings.AllowGroups = [ "wheel" ];
        settings.AllowTcpForwarding = "no";
        settings.ClientAliveCountMax = 2;
        settings.MaxAuthTries = 3;
        settings.MaxSessions = 2;
        settings.TCPKeepAlive = "no";
        settings.AllowAgentForwarding = "no";
      };
      #services.prometheus.enable = true;
      #services.icingaweb2.enable = true;
      users.mutableUsers = false;

      sops = {
        defaultSopsFile = rootPath + "/secrets/shared.yaml";
        age = {
          keyFile = "/var/lib/sops-nix/key.txt";
        };
        secrets = {
          "telegram/bot_token" = { };
          "telegram/group_id" = { };
        };
      };

      system.stateVersion = "23.11";
      nix.gc = {
        automatic = true;
      };

      security.sudo.wheelNeedsPassword = true;

      services.nginx = {
        enable = true;
        virtualHosts.localhost = {
          forceSSL = true;
          listen = [
            {
              port = 442;
              addr = "0.0.0.0";
              ssl = true;
            }
          ];
          #onlySSL = true;
          #listen = [{
          #addr = "localhost";
          #port = 443;
          #ssl = true;
          #}];
          locations."/" = {
            return = "200 '<html><body>It works</body></html>'";
            extraConfig = ''
              default_type text/html;
            '';
          };
          sslCertificate = "/etc/nixos-selfsigned.crt";
          sslCertificateKey = "/etc/nixos-selfsigned.key";
        };
      };

      services.logrotate.enable = true;
      services.logrotate.checkConfig = false;

      # Lighthouse flavor comes from inputs.self.modules.nixos.nebula-lighthouse
      # (roster-derived); what stays host-local:
      services.nebula.networks.mesh = {
        # the zabbix proxy agent must stay reachable over the mesh
        firewall.inbound = [
          {
            cidr = constants.nebula.cidr;
            port = "10050";
            proto = "any";
          }
        ];
      };
      # cert/key material lives on the persistent btrfs root
      mesh.nebulaSecretDir = "/nix/persist/etc/nebula";

      # 1 GB RAM, 10 GB disk: earlyoom as the OOM safety net, swap-inflation
      # sysctls tuned for zram, and MemoryMax ceilings on every service so one
      # runaway process cannot starve the rest of the machine.
      commonMem.enable = true;
    };
}
