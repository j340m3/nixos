# User actions — runbook (2026-10-17)

Ordered checklist. Editing secrets needs the admin age key (not on the dev
machine). After any repo edit: `git add … && git commit && git push` — fleet
hosts build from GitHub (comin), on a host `sudo systemctl restart comin`
(check the exact unit: `systemctl list-units --no-pager | grep -i comin`)
re-triggers it if you're too impatient.

## 1. mrpotatohead: re-cut nebula cert to 10.0.0.6 (blocks nothing, do first)

It currently runs mesh IP `10.0.0.5` (= buzz's address). Until fixed, mesh
routing to buzz and to mrpotatohead is ambiguous.

1. Regenerate the cert (CA key lives on your side; the repo helper can do it —
   discover its args first):
   ```bash
   python3 scripts/rotate-secrets.py nebula-cert --help
   # then regenerate the mrpotatohead host cert with address 10.0.0.6
   ```
   Manual equivalent (on machine with ca.crt + ca.key):
   ```bash
   nebula-cert sign -ca-crt ca.crt -ca-key ca.key \
     -name mrpotatohead -ip 10.0.0.6/24
   ```
2. Put the new cert into the host secrets (replaces the old base64 blob):
   ```bash
   sops secrets/hosts/mrpotatohead/secrets.yaml   # swap nebula/self_crt
   # while you're in sops: if secrets/shared.yaml has a
   # hosts.mrpotatohead.ip.nebula entry, change it to 10.0.0.6 too:
   sops secrets/shared.yaml
   ```
3. Push and let mrpotatohead rebuild, then verify on the host:
   ```bash
   ssh mrpotatohead  # (or however you reach it)
   nebula-cert print -in /etc/nebula/self.crt   # must show 10.0.0.6
   ```

## 2. WireGuard on mrpotatohead (config already in repo, verify after rebuild)

```bash
ip a            # wg0 UP, 10.66.66.1/24 (same server key/pool as the other three)
iptables-save | grep ens6    # NAT masquerade goes out ens6
```

## 3. Reticulum identities

Each member host has a Reticulum identity in `secrets/hosts/<host>/reticulum.yaml`
(key `identity`, base64). The public transport hash and the Nix `rnsh`
destination hash live in `global/constants.nix` under `reticulum.identities`.

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
`modules/wifi.nix`.

## 5. mrpotatohead remotebuild pubkey (paste slot already waiting)

```bash
sops -d secrets/hosts/mrpotatohead/secrets.yaml | yq -r '.remotebuild.pub'
# paste the ssh-ed25519 line into modules/remote-builder.nix authorizedKeys
# (commented slot marked "root@mrpotatohead")
```

## 6. Loose ends (say the word and I'll take one of them)

- **buzz: nebula 4242 blocked by its own firewall** — only UDP 53 is open,
  so fleet members can't actually dial buzz's endpoint. Fix is repo-side
  (`allowedUDPPorts = [ 53 4242 ]` in buzz) — I can commit it.
- Rotate the admin password (initial hash still in git history).
- totp keys in rex/woody/pricklepants yamls are unconsumed — sops-clean them.
- Endpoints in `global/constants.nix` are leased (DHCP/DHCPv6) — re-check
  `ip a` on the VPSs if peering ever acts up; roster comment says so too.
