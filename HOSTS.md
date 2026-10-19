# Hosts

Every folder in `modules/hosts/` is a
`nixosConfiguration`: each host folder declares itself via a one-line
`flake-parts.nix` (see [README "Adding a host"](./README.md#adding-a-host)).
The folder name is the host name. This file is the human-readable map.

| Host | Class | Role | Notes |
|---|---|---|---|

Roles as of 2026-10-18, verified against the import graph.

| `lenny` | laptop | graphical | XFCE. Users: jeromeb, lilly. Old ThinkPad X230. |
| `rex` | VM (on laptop) | graphical | Work laptop VM. XFCE, k3s, nebula, rclone, home-manager. |
| `sid` | WSL | graphical | NixOS-WSL on Windows. NVIDIA, editor. |
| `slinky` | uConsole (aarch64) | graphical | Raspberry Pi 4 / oom-hardware uConsole, nebula, wifi. |
| `woody` | server | graphical | Homeserver: prometheus/grafana/fritz-exporter, zabbix web+agent, immich, paperless, harmonia binary cache, borg-server, loghost, NFS-fee, reticulum, mosquitto. KDE via xrdp (no display manager). |
| `zurg` | laptop | graphical | ThinkPad P51. stylix, gaming, llm, fingerprint, DE. |
| `bootstrap` | image | headless | Disko image for provisioning new hosts. |
| `bootstrap-impermanent` | image | headless | Disko image, impermanent-root variant. |
| `buzz` | VPS (Ionos) | headless | nextcloud, dnsdist DoT/53 (the "pihole"), wireguard, remote-builder. Currently offline — Ionos panel check pending; vaultwarden moved to pricklepants. |
| `jessie` | server | headless | minecraft-bedrock + minecraft-java (Paper via nix-minecraft, 1G heap), radicle-seed, wireguard, remote-builder, acme, persistence. |
| `mrpotatohead` | VPS | headless | nextcloud (nginx/php-fpm), wireguard, hardening, disko LVM/btrfs, upgrade-health auto-rollback. |
| `pricklepants` | VPS (Ionos) | headless | vaultwarden, luanti/minetest, wireguard VPN -> UK, bridge home, nebula lighthouse with mesh DNS, remote-builder, yggdrasil. |

## Graphical

### lenny

Lillys Laptop. X230, XFCE. Host-local user modules `jeromeb/` and `lilly/`.

### rex

VM on Laptop (work). k3s, nebula, google-drive, XFCE, home-manager module.

### sid

NixOS on WSL. `wsl.enable`, `wsl.defaultUser = "nixos"`, NVIDIA, editor.

### slinky

uConsole (Raspberry Pi 4, aarch64). Uses oom-hardware uConsole modules and a
locally built rpi4 kernel. Nebula, wifi.

### woody

Homeserver. prometheus/grafana/fritz-exporter, zabbix web + agent, immich,
paperless, harmonia binary cache, borg-server, loghost, NFS-fee, reticulum,
mosquitto. KDE reachable via xrdp (no local display manager).

### zurg

ThinkPad P51 daily driver. stylix, gaming, llm, fingerprint, terminal, DE.

## Headless

### bootstrap / bootstrap-impermanent

Disko-based images used to provision hosts. `bootstrap` is a normal root;
`bootstrap-impermanent` uses an ephemeral root. Built via
`packages.x86_64-linux.image[-impermanent]`.

### buzz

VPS on Ionos. nextcloud, dnsdist-based public DoT resolver ("pihole" role),
wireguard, remote-builder. Offline at the moment (Ionos panel check pending;
nebula identity repair in flight). vaultwarden used to run here — now on
pricklepants. Also a declaratively-enrolled remote builder.

### jessie

Server. minecraft-bedrock, minecraft-java (Paper via nix-minecraft, 1G heap,
Aikar flags, view/simulation distance reduced for the 1-core/1.8GB box),
radicle-seed, wireguard, remote-builder, acme, persistence, nebula.

### mrpotatohead

VPS. nextcloud (nginx/php-fpm), wireguard, hardening, disko LVM/btrfs disk
layout, and the upgrade-health module (`upgradeHealth.enable = true`) which
rolls back and reboots if systemd reports a failed unit after
`switch-to-configuration`.

### pricklepants

VPS on Ionos. vaultwarden, luanti/minetest, wireguard VPN to the UK, bridge
home, nebula lighthouse with mesh DNS, remote-builder, yggdrasil. Also a
declaratively-enrolled remote builder.

## Retired / not in this flake

Mentioned historically but currently have no folder under `hosts/`:

- `bopeep` — laptop of my mom
- `hamm` — PVS on Ionos, wireguard VPN -> Germany
- `andy` — my phone
