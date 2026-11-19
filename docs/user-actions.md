# User actions — runbook (2026-10-17, updated 2026-11-19)

Ordered checklist. Editing secrets needs the admin age key (not on the dev
machine). After any repo edit: `git add … && git commit && git push` — fleet
hosts build from GitHub (comin), on a host `sudo systemctl restart comin`
(check the exact unit: `systemctl list-units --no-pager | grep -i comin`)
re-triggers it if you're too impatient.

## 0. Nebula root rotation (new: automated by `just nebula-rotate`)

A full root-CA rotation tool now exists (`scripts/rotate-secrets.py
nebula-root`, docs in [secrets-101](secrets-101.md#rotate-the-root-ca-full-mesh-rotation)):
it generates the new root, re-signs every host cert, unifies the mesh IPs into
`modules/global/_constants.nix`, and fixes mrpotatohead's `10.0.0.5`-for-`10.0.0.6`
identity clash below automatically (dry-run by default — review, then `--yes`).

## 1. mrpotatohead: verify on-host nebula cert is 10.0.0.6 (roster already unified)

The `just nebula-rotate` pass moved the roster IPs into
`modules/global/_constants.nix` (mrpotatohead = 10.0.0.6). The remaining check
is on the host after its next rebuild:

```bash
ssh mrpotatohead  # (or however you reach it)
nebula-cert print -in /etc/nebula/self.crt   # must show 10.0.0.6
```

If it still prints `10.0.0.5`, re-sign with the helper (CA key on your side):
`python3 scripts/rotate-secrets.py nebula-cert --help`.

## 2. WireGuard on mrpotatohead (config already in repo, verify after rebuild)

```bash
ip a            # wg0 UP, 10.66.66.1/24 (same server key/pool as the other three)
iptables-save | grep ens6    # NAT masquerade goes out ens6
```

## 3. Reticulum identities

Each member host has a Reticulum identity in `secrets/hosts/<host>/reticulum.yaml`
(key `identity`, base64). The public transport hash and the Nix `rnsh`
destination hash live in `modules/global/_constants.nix` under `reticulum.identities`.

To rotate one host:

```bash
NIXPKGS_ALLOW_UNFREE=1 nix shell --impure nixpkgs#python3Packages.rns -c bash -c '
  rnid -g /tmp/identity
  rnid -i /tmp/identity -p
  rnid -i /tmp/identity -H "rnsh"
'
sudo sops secrets/hosts/<host>/reticulum.yaml   # set identity to base64 of /tmp/identity
```

Update `reticulum.identities.<host>.hash` and `.nix`, rebuild that host and the
public transports, then check with `rnstatus` and `rnprobe <nix-destination>`.

## 4. wifi secret format spot-check (works only if values are FOO=bar lines)

```bash
ssh <host-with-wifi>  # woody/lenny/slinky
sudo head -1 /run/secrets/wifi/phone/ssid    # MUST read PHONE_SSID=…
```

If it's a bare value, profiles break silently — tell me and I'll restructure
`modules/services/wifi.nix`.

## 5. Loose ends (say the word and I'll take one of them)

- **Note (not a task):** nixpkgs 26.11 removed Nextcloud's declarative
  `adminuser`/`adminpassFile`. An existing install keeps its admin in the DB;
  a fresh install needs `nextcloud-occ user:add <name>` + `nextcloud-occ
  group:adduser admin <name>` (password in sops `nextcloud-admin-pass`).
- Rotate the admin password (initial hash still in git history).
- Endpoints in `modules/global/_constants.nix` are leased (DHCP/DHCPv6) — re-check
  `ip a` on the VPSs if peering ever acts up; roster comment says so too.
