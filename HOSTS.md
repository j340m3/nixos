# Hosts

Every folder in `modules/hosts/` is a
`nixosConfiguration`: each host folder declares itself via a one-line
`flake-parts.nix` (see [README "Adding a host"](./README.md#adding-a-host)).
The folder name is the host name. This file is the human-readable map.

| Host | Class | Role | Notes |
|---|---|---|---|
| `lenny` | laptop | graphical | XFCE. Users: jeromeb, lilly. Old ThinkPad X230. |
| `rex` | VM (on laptop) | graphical | Work laptop VM. XFCE, k3s, nebula, rclone, home-manager. |
| `sid` | WSL | graphical | NixOS-WSL on Windows. NVIDIA, editor. |
| `slinky` | uConsole (aarch64) | graphical | Raspberry Pi 4 / nixos-uconsole + nixos-raspberrypi, vendor kernel, nebula, wifi. |
| `woody` | server | graphical | Homeserver: prometheus/grafana/fritz-exporter, immich, paperless, harmonia binary cache + artifact publisher, borg-server, loghost, NFS-fee, mosquitto. KDE via xrdp (no display manager). |
| `zurg` | laptop | graphical | ThinkPad P51. Intentionally minimal aspect set (no `system-default`): agent-md, nebula, node-exporter, run0-admin, sops, update, logging, stylix + the P51 nixos-hardware profile. |
| `bootstrap` | image | headless | Disko image for provisioning new hosts. |
| `bootstrap-impermanent` | image | headless | Disko image, impermanent-root variant. |
| `buzz` | VPS (Ionos) | headless | dnsdist DoT/53 (the "pihole"), wireguard, nebula lighthouse, remote-builder. Currently offline — Ionos panel check pending; vaultwarden moved to pricklepants, nextcloud to mrpotatohead. Reachable via DNS: `buzz.hosts.kauderwels.ch`. |
| `jessie` | server | headless | minecraft-bedrock + minecraft-java (Paper via nix-minecraft, 1G heap), radicle-seed, wireguard, remote-builder, acme, persistence. Reachable via DNS: `jessie.hosts.kauderwels.ch`. |
| `mrpotatohead` | VPS | headless | nextcloud (nginx/php-fpm), wireguard, hardening, disko LVM/btrfs, upgrade-health auto-rollback. Reachable via DNS: `mrpotatohead.hosts.kauderwels.ch`. |
| `pricklepants` | VPS (Ionos) | headless | vaultwarden, luanti/minetest, wireguard VPN -> UK, bridge home, nebula lighthouse with mesh DNS, remote-builder, reticulum. Reachable via DNS: `pricklepants.hosts.kauderwels.ch`. |

Roles as of 2026-11-19, verified against the import graph. `zurg` deliberately
does not import `system-default`; its host module lists every aspect it uses.

## Logging (updated 2026-11-19)

`services/logging` (ex `modules/_logging.nix`) forwards every mesh host's
journald over nebula to woody rsyslog (TCP 10.0.0.3:514); woody archives
per host under `/persist/rsyslog/<host>/`, `services/log-watchdog` alerts
when a monitored host goes silent >48h.

- forwarding today: woody (own journal locally), jessie, mrpotatohead,
  pricklepants, zurg (enrolled 2026-11-17).
- imported but idle until updated (watchdog `expectedOff`): lenny, rex,
  slinky, buzz.
- NOT covered: sid (WSL) and the bootstrap images.

Zurg is deliberately outside `system-default`: it imports `agent-md`,
`nebula`, `node-exporter`, `run0-admin`, `sops`, `update`, `logging`,
`stylix` and the P51 nixos-hardware profile — and nothing else (zram, ssh,
locale, domain, peerpatrol, distributed-builds, DE and home-manager are
intentionally absent).

## Graphical

### lenny

Lillys Laptop. X230, XFCE. Host-local user modules `jeromeb/` and `lilly/`.

### rex

VM on Laptop (work). k3s, nebula, google-drive, XFCE, home-manager module.

### sid

NixOS on WSL. `wsl.enable`, `wsl.defaultUser = "nixos"`, NVIDIA, editor.

### slinky

uConsole (Raspberry Pi 4, aarch64). Built on the community
[nixos-uconsole](https://github.com/nixos-uconsole/nixos-uconsole) modules on
top of [nvmd/nixos-raspberrypi](https://github.com/nvmd/nixos-raspberrypi)
(both inputs follow the fleet nixpkgs pin; vendor kernel 6.12 with the
uconsole patch set). Generational `boot.loader.raspberry-pi` kernel boot.
Kernel cacheable via the ADR-0018 artifact publisher on woody. Nebula, wifi.
See [ADR-0019](./docs/adr/0019-slinky-nixos-uconsole.md).

### woody

Homeserver. prometheus/grafana/fritz-exporter, immich, paperless, harmonia
binary cache + artifact publisher, borg-server, loghost, NFS-fee, mosquitto.
KDE reachable via xrdp (no local display manager). Zabbix was retired
2026-11-12.

### zurg

ThinkPad P51 daily driver. stylix, gaming, llm, fingerprint, terminal, DE.

## Headless

### bootstrap / bootstrap-impermanent

Disko-based images used to provision hosts. `bootstrap` is a normal root;
`bootstrap-impermanent` uses an ephemeral root. Built via
`packages.x86_64-linux.image[-impermanent]`.

### buzz

VPS on Ionos. dnsdist-based public DoT resolver ("pihole" role), wireguard,
nebula lighthouse, remote-builder. Offline at the moment (Ionos panel check
pending; nebula identity repair in flight). vaultwarden used to run here — now
on pricklepants; nextcloud moved to mrpotatohead. Also a declaratively-enrolled
remote builder.

### jessie

Server. minecraft-bedrock, minecraft-java (Paper via nix-minecraft, 1G heap,
Aikar flags, view/simulation distance reduced for the 1-core/1.8GB box),
radicle-seed, wireguard, remote-builder, acme, persistence, nebula.
Reachable via DNS: `jessie.hosts.kauderwels.ch`.

### mrpotatohead

VPS. nextcloud (nginx/php-fpm), wireguard, hardening, disko LVM/btrfs disk
layout, and the upgrade-health module (`upgradeHealth.enable = true`) which
rolls back and reboots if systemd reports a failed unit after
`switch-to-configuration` (rollback is opt-in via
`upgradeHealth.rollback.enable = true`; when false it only notifies).

### pricklepants

VPS on Ionos. vaultwarden, luanti/minetest, wireguard VPN to the UK, bridge
home, nebula lighthouse with mesh DNS, remote-builder, reticulum.
Also a declaratively-enrolled remote builder.

## Retired / not in this flake

Mentioned historically but currently have no folder under `hosts/`:

- `bopeep` — laptop of my mom
- `hamm` — PVS on Ionos, wireguard VPN -> Germany
- `andy` — my phone
