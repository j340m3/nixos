# Hosts

Every folder in `hosts/graphical/` and `hosts/headless/` is a
`nixosConfiguration` auto-discovered by `flake.nix`. The folder name is the
host name. This file is the human-readable map.

| Host | Class | Role | Notes |
|---|---|---|---|
| `lenny` | laptop | graphical | XFCE. Users: jeromeb, lilly. Old ThinkPad X230. |
| `rex` | VM (on laptop) | graphical | Work laptop VM. XFCE, k3s, nebula, google-drive, home-manager. |
| `sid` | WSL | graphical | NixOS-WSL on Windows. NVIDIA, editor. |
| `slinky` | uConsole (aarch64) | graphical | Raspberry Pi 4 / oom-hardware uConsole, nebula, wifi. |
| `woody` | server | graphical | Homeserver: Home Assistant, MQTT, borg-server, remote-builder, acme, loghost, reticulum. |
| `zurg` | laptop | graphical | ThinkPad P51. stylix, gaming, llm, fingerprint, DE. |
| `bootstrap` | image | headless | Disko image for provisioning new hosts. |
| `bootstrap-impermanent` | image | headless | Disko image, impermanent-root variant. |
| `buzz` | VPS (Ionos) | headless | vaultwarden. |
| `jessie` | server | headless | minecraft-bedrock, radicle-seed, wireguard, remote-builder, acme, persistence. |
| `mrpotatohead` | VPS | headless | nextcloud (nginx/php-fpm), hardening, upgrade-health auto-rollback enabled. |
| `pricklepants` | VPS (Ionos) | headless | wireguard VPN -> UK, bridge home, nebula lighthouse. |

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

Homeserver. Home Assistant, MQTT, borg-server, remote-builder, acme, loghost,
reticulum.

### zurg

ThinkPad P51 daily driver. stylix, gaming, llm, fingerprint, terminal, DE.

## Headless

### bootstrap / bootstrap-impermanent

Disko-based images used to provision hosts. `bootstrap` is a normal root;
`bootstrap-impermanent` uses an ephemeral root. Built via
`packages.x86_64-linux.image[-impermanent]`.

### buzz

VPS on Ionos. vaultwarden. Also a declaratively-enrolled remote builder.

### jessie

Server. minecraft-bedrock, radicle-seed, wireguard, remote-builder, acme,
persistence, nebula.

### mrpotatohead

VPS. nextcloud (nginx/php-fpm), hardening, and the upgrade-health module
(`upgradeHealth.enable = true`) which rolls back and reboots if systemd reports
a failed unit after `switch-to-configuration`.

### pricklepants

VPS on Ionos. Wireguard VPN to the UK, bridge home, nebula lighthouse. Also a
declaratively-enrolled remote builder.

## Retired / not in this flake

Mentioned historically but currently have no folder under `hosts/`:

- `bopeep` — laptop of my mom
- `hamm` — PVS on Ionos, wireguard VPN -> Germany
- `andy` — my phone
