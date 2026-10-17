# Yggdrasil backup overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand yggdrasil up as a second, fleet-meshed overlay so remote builds and the harmonia cache keep working when the nebula overlay is degraded.

**Architecture:** All ygg facts live in `global/constants.nix` (per-host `ygg` address + `yggPub` node pubkey, `yggPort`, harvest recipe). `modules/yggdrasil.nix` becomes the real member module (peers dial the lighthouses' *public endpoints* over tls, lighthouses listen + open WAN port, `AllowedPublicKeys` pins fleet box pubkeys). Membership rides the nebula chain; an active builder gets **two** `nix.buildMachines` entries (nebula alias primary at speedFactor 10, `-ygg` secondary at speedFactor 1) dialed by ssh alias so the remotebuild identity applies; the cache gains its old `cache.kauderwels.ch` substituter back, with harmonia opening 443 on the ygg interface only.

**Tech Stack:** NixOS modules, specialArgs-injected `constants`, `nix eval` attribute checks as the test harness, git commits per task.

**Spec:** `docs/superpowers/specs/2026-10-17-yggdrasil-backup-design.md`

## Global Constraints

- Pre-harvest state must eval green: every new constant is `null`-guarded; no host may fail `nix eval .#nixosConfigurations.<h>.config.system.build.toplevel.drvPath` (11 x86 hosts: `lenny rex sid woody zurg pricklepants buzz jessie mrpotatohead bootstrap bootstrap-impermanent`; `slinky` is aarch64, skip it).
- Eval command shape (known-good): `nix eval .#nixosConfigurations.<host>.config.<attr>`; `--raw` cannot print Booleans. Per-host eval may need a >60s timeout.
- All files that reference `constants.*` receive them via module args (`constants` is in specialArgs; add it to the file's `{ ..., constants, ... }` arg set). Unused args get flagged by the `deadnix` pre-commit hook.
- Host roster note: `constants.host` contains exactly the 5 verified hosts (pricklepants, buzz, woody, mrpotatohead, jessie); lenny/rex are pending their nebula address verification — never index `constants.host.<name>` without an `or {}`/`or null` fallback.
- Yggdrasil enumerate keys are JSON-ish snake/lowercase strings passed verbatim (`"Peers"`, `"Listen"`, `"IfName"`, `"AllowedPublicKeys"`).
- `yggPort = 1337` everywhere; must not appear anywhere else in the repo today (grep verified empty).

## Review Focus

- A host whose name is missing from `constants.host` (lenny/rex) importing `modules/yggdrasil.nix` must not crash eval — expect `null`-guarded `defaults`, peers still derived (no address for itself). Test: the eval in Task 2 for `lenny`.
- The two inline lighthouse hosts (pricklepants, buzz) must end up with exactly one ygg module activation (no double import), while non-lighthouse members get peers, not listeners. Tests: Tasks 2–3 evals for `buzz` vs `lenny`.
- Pre-harvest (`ygg = null`) must produce exactly today's behavior: 5 buildMachines (no `-ygg` twins), `hostNames` = 2 entries, no `pricklepants-ygg` ssh block. Tests: Task 4/5 evals with `null`-state expectations.
- After harvest, `AllowedPublicKeys` must list only fleet pubkeys (no literal keys in modules). Test: Task 2 eval (empty pre-harvest) + code inspection step.
- The cache surface on ygg must be 443-only (no 80/5000). Test: Task 6 eval on woody.

---

### Task 1: Constants — ygg facts in the roster

**Files:**
- Modify: `global/constants.nix`

**Interfaces:**
- Consumes: existing `host {...}`, `lighthouses`, `sshPort` let-bindings.
- Produces: `host.<name>.ygg` (address or `null`), `host.<name>.yggPub` (box pubkey or `null`) for the 5 roster hosts; top-level `yggPort = 1337`; let-binding comment documenting the harvest recipe.

- [ ] **Step 1: Edit the let-bindings**

  - On each of the 5 host entries add `ygg = null; yggPub = null;` (pricklepants/buzz already have `ip`/`endpoints`, keep those intact).
  - Add at the `let` level, after `sshPort`:

    ```nix
    # Yggdrasil backup overlay facts: address + node box pubkey harvested via
    # `yggdrasilctl getSelf` per host (after first boot with persistentKeys).
    # null until harvested; consumers are null-guarded. Addresses and box
    # pubkeys are public facts, not secrets. AllowedPublicKeys pinning happens
    # in modules/yggdrasil.nix from these values.
    yggPort = 1337;
    ```

  - In the returned attrset change `inherit host lighthouses sshPort;` to `inherit host lighthouses sshPort yggPort;`.

- [ ] **Step 2: Eval check (constants are standalone-importable, pure builtins)**

  ```bash
  nix eval --raw --expr '(import ./global/constants.nix).yggPort' ; echo
  nix eval --json --expr 'builtins.attrNames (import ./global/constants.nix).host'
  nix eval --raw --expr '(import ./global/constants.nix).host.pricklepants.ygg or "NULLGUARD-OK"' ; echo
  ```

  Expected: `1337`; `["buzz","jessie","mrpotatohead","pricklepants","woody"]`; `NULLGUARD-OK`.

- [ ] **Step 3: Commit**

  ```bash
  git add global/constants.nix
  git commit -m "constants: ygg address/pubkey tiles + yggPort"
  ```

### Task 2: The yggdrasil member module

**Files:**
- Rewrite: `modules/yggdrasil.nix` (26 lines → ~70)

**Interfaces:**
- Consumes: `constants.host.*.ygg`/`.yggPub`, `constants.lighthouses`, `constants.yggPort`, `config.networking.hostName`.
- Produces (later tasks + harvest rely on): `services.yggdrasil.enable = true` on every mesh member; settings.Peers = `tls://<lighthouse-endpoint-host>:1337` for every *other* lighthouse (non-lighthouse only); settings.Listen = `["tcp://0.0.0.0:1337"]` + `networking.firewall.allowedTCPPorts` containing 1337 (lighthouses only); `"AllowedPublicKeys"` = non-null `constants.host.*.yggPub` values; fixed `IfName = "ygg"`; `persistentKeys = true`.

- [ ] **Step 1: Rewrite the module**

  Replace the whole file (it is the skeleton):

  ```nix
  {
    config,
    lib,
    pkgs,
    constants,
    ...
  }:
  let
    hostName = config.networking.hostName;
    # roster entry is optional: lenny/rex/slinky have no constants.host entry yet
    me = constants.host.${hostName} or { };
    isLighthouse = builtins.elem hostName constants.lighthouses;
    # lighthouses' public endpoints minus the trailing ":4242" (nebula udp),
    # reused as ygg tls peer hosts
    endpointHost =
      ep: builtins.concatStringsSep ":" (builtins.dropEnd 1 (builtins.splitString ":" ep));
    peerLighthouses = builtins.filter (h: h != hostName) constants.lighthouses;
    # one tls URI per *endpoint* of each peer lighthouse (the nebula ":4242"
    # suffix is stripped, replaced by the ygg port) — ygg tries them all
    yggPeers = builtins.concatMap
      (h: map (ep: "tls://${endpointHost ep}:${toString constants.yggPort}") (constants.host.${h}.endpoints or [ ]))
      peerLighthouses;
    fleetKeys = builtins.filter (k: k != null) (
      map (n: constants.host.${n}.yggPub or null) (builtins.attrNames constants.host)
    );
  in
  {
    services.yggdrasil = {
      enable = true;
      openMulticastPort = true;
      persistentKeys = true;
      settings = {
        "Peers" = lib.mkIf (!isLighthouse) (lib.flatten yggPeers);
        "Listen" = lib.mkIf isLighthouse [ "tcp://0.0.0.0:${toString constants.yggPort}" ];
        "AllowedPublicKeys" = fleetKeys;
        "IfName" = "ygg";
        "IfMTU" = 65535;
      };
    };

    # lighthouses accept WAN peerings; members only ever dial out
    networking.firewall.allowedTCPPorts = lib.mkIf isLighthouse [ constants.yggPort ];
  }
  ```

- [ ] **Step 2: Eval checks (pre-harvest green state)**

  ```bash
  nix eval .#nixosConfigurations.lenny.config.services.yggdrasil.enable   # true (lenny imports nebula in manifest)
  nix eval --json .#nixosConfigurations.woody.config.services.yggdrasil.settings.Peers   # 4 URIs (2 per lighthouse), each tls://...:1337
  nix eval .#nixosConfigurations.woody.config.services.yggdrasil.settings."AllowedPublicKeys"  # want []
  nix eval .#nixosConfigurations.woody.config.services.yggdrasil.settings."IfName"  # "ygg"
  ```

  Expected: enable=true; 4 `tls://...` URIs ending `:1337`; `[]`; `"ygg"`. (`lenny` has no `constants.host` entry — this proves the `or {}` guard.)

- [ ] **Step 3: Commit**

  ```bash
  git add modules/yggdrasil.nix
  git commit -m "yggdrasil: fleet member module over nebula lighthouse endpoints"
  ```

### Task 3: Membership wiring (nebula chain + two inline lighthouses)

**Files:**
- Modify: `modules/nebula.nix:12` — `imports = [ ./remote-builder.nix ];` → `imports = [ ./remote-builder.nix ./yggdrasil.nix ];`
- Modify: `hosts/headless/pricklepants/default.nix` — after the `../../../modules/remote-builder.nix` line (line 32) add `../../../modules/yggdrasil.nix` with the one-line comment `# yggdrasil backup overlay member (inline nebula host)`.

- Modify: `hosts/headless/buzz/default.nix` — same insertion after its `../../../modules/remote-builder.nix` line (line 42) with the same comment.

**Interfaces:**
- Consumes: Task 2 module.
- Produces: `services.yggdrasil.enable = true` on all 7 mesh members (and nothing on sid/zurg/bootstraps); the two lighthouses also get `settings.Listen` + firewall 1337.

- [ ] **Step 1: Apply the three edits** (they are one-line insertions; keep the exact comment wording above so grep-verification matches).

- [ ] **Step 2: Eval checks**

  ```bash
  for h in lenny rex woody jessie mrpotatohead; do
    nix eval ".#nixosConfigurations.$h.config.services.yggdrasil.enable"; done        # true ×5
  for h in pricklepants buzz; do
    nix eval '.#nixosConfigurations.'"$h"'.config.services.yggdrasil.settings."Listen"'; done # one URI each
  for h in sid zurg bootstrap bootstrap-impermanent; do
    nix eval ".#nixosConfigurations.$h.config.services.yggdrasil.enable"; done          # false ×4
  nix eval .#nixosConfigurations.pricklepants.config.networking.firewall.allowedTCPPorts   # contains 1337
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add modules/nebula.nix hosts/headless/pricklepants/default.nix hosts/headless/buzz/default.nix
  git commit -m "mesh: yggdrasil rides the nebula membership chain"
  ```

### Task 4: Distributed builds — alias dialing + ygg secondary

**Files:**
- Rewrite: `modules/common/distributed-builds.nix` (44 lines)

**Interfaces:**
- Consumes: `constants.buildHosts`, `constants.host.<n>.ygg`, `constants.sshPort`;
- Produces (eval/ssh config rely on): for each peer `h`: primary machine entry `{ hostName = h; …speedFactor = 10; }`; secondary `{ hostName = "h-ygg"; …speedFactor = 1; }` **only when** `constants.host.${h}.ygg or null != null`; ssh config `Host ${h}` (HostName = nebula ip) and `Host ${h}-ygg` (HostName = ygg addr) blocks, both with `User remotebuild`, `Port ${sshPort}`, `IdentitiesOnly yes`, `IdentityFile /root/.ssh/remotebuild`.

- [ ] **Step 1: Rewrite the module**

  Full final file (44 lines today; ssh blocks govern identity/port/user so the
  buildMachines entries carry no `user`/`port` fields):

  ```nix
  { pkgs, lib, config, constants, ... }:
  let
    inventory = constants.buildHosts;
    peers = lib.filterAttrs (h: _: h != config.networking.hostName) inventory;
    # ygg backup address per peer (null until harvested from yggdrasilctl)
    yggAddr = h: constants.host.${h}.ygg or null;
    sshBlock = h: host: ''
      Host ${h}
        HostName ${host}
        Port ${toString constants.sshPort}
        User remotebuild
        IdentitiesOnly yes
        IdentityFile /root/.ssh/remotebuild
    '';
    machines = lib.flatten (
      lib.mapAttrsToList
        (h: v: [
          {
            # primary: nebula path wins via speedFactor; dials by alias so the
            # ssh-config block (not the raw IP) applies identity + port
            hostName = h;
            systems = v.systems or [ "x86_64-linux" ];
            speedFactor = 10;
            protocol = "ssh-ng";
            supportedFeatures = v.supportedFeatures or [ ];
            maxJobs = v.maxJobs or 4;
          }
        ]
        ++ lib.optionals (yggAddr h != null) [
          {
            hostName = "${h}-ygg";
            systems = v.systems or [ "x86_64-linux" ];
            speedFactor = 1; # backup path only
            protocol = "ssh-ng";
            supportedFeatures = v.supportedFeatures or [ ];
            maxJobs = v.maxJobs or 4;
          }
        ])
        peers
    );
  in
  {
    nix.distributedBuilds = true;
    nix.settings.builders-use-substitutes = true;
    nix.buildMachines = machines;

    programs.ssh.extraConfig = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (h: v: sshBlock h v.connect) peers
      ++ lib.mapAttrsToList (h: v: lib.optionals (yggAddr h != null) [ (sshBlock "${h}-ygg" (yggAddr h)) ]) peers
    );

    # remotebuild user/group live in ../remote-builder.nix (accept side),
    # pulled in by nebula.nix for every mesh member.

    sops.secrets."remotebuild/key" = { ... }; # unchanged, keep as-is
    sops.secrets."remotebuild/pub" = { ... }; # unchanged, keep as-is
  }
  ```

- [ ] **Step 2: Eval checks (pre-harvest: no `-ygg` twins)**

  ```bash
  nix eval --json '.#nixosConfigurations.lenny.config.nix.buildMachines' | jq '[.[].hostName]'   # ["pricklepants","buzz","mrpotatohead","jessie","woody"], each speedFactor 10
  nix eval --raw '.#nixosConfigurations.lenny.config.programs.ssh.extraConfig' | grep -c 'pricklepants-ygg' ; true   # absent (0) pre-harvest
  nix eval --raw '.#nixosConfigurations.lenny.config.programs.ssh.extraConfig' | grep -c 'IdentityFile /root/.ssh/remotebuild'   # 5
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add modules/common/distributed-builds.nix
  git commit -m "builders: dial by ssh alias, ygg secondary machine entries"
  ```

### Task 5: knownHosts cover the ygg addr

**Files:**
- Modify: `modules/common/ssh-identities.nix:16`

**Interfaces:**
- Consumes: `constants.host.<n>.ygg`.
- Produces: `hostNames = [ h v.connect ] ++ (optional ygg addr)`.

- [ ] **Step 1: Edit the mapAttrs body**

  ```nix
  services.openssh.knownHosts =
    lib.mapAttrs (h: v: {
      hostNames = [ h v.connect ]
        ++ (lib.optional ((constants.host.${h}.ygg or null) != null)
              constants.host.${h}.ygg);
      publicKey = lib.fileContents (../../secrets/common/ssh + "/${h}/ssh.pub");
    }) constants.buildHosts;
  ```

- [ ] **Step 2: Eval check (pre-harvest: unchanged)**

  ```bash
  nix eval --json .#nixosConfigurations.lenny.config.services.openssh.knownHosts.pricklepants.hostNames
  ```

  Expected: `["pricklepants","10.0.0.1"]`.

- [ ] **Step 3: Commit**

  ```bash
  git add modules/common/ssh-identities.nix
  git commit -m "ssh: cover builder ygg addresses in knownHosts"
  ```

### Task 6: Cache — substituter back, 443 on ygg only

**Files:**
- Modify: `modules/common/update.nix:100,105` — un-comment the pair:

  ```nix
  substituters = [
    "https://cache.nixos.org"
    "https://cache.kauderwels.ch"
    "https://nix-community.cachix.org"
    "https://cache.chaotic.cx"
  ];
  trusted-public-keys = [
    "cache.kauderwels.ch:0fswEglSoELjSBSMOuvnLAXMstePxzeTmOTYziR7z+Y="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "chaotic.cachix.org-1:Zf7C6GVRqJjU8B/ihd+psPVKp3/7Or/FSvOP3/9aB8Y="
  ];
  ```

- Modify: `modules/harmonia.nix` — after the nebula.inbound `lib.mkIf` block (ends line 40), append the ygg counterpart:

  ```nix
  # cache reachable over the yggdrasil backup overlay — TLS only (no 80/5000)
  networking.firewall.interfaces."ygg".allowedTCPPorts = lib.mkIf
    (config.services.harmonia.cache.enable && config.services.yggdrasil.enable) [ 443 ];
  ```

**Interfaces:**
- Consumes: Task 3 (`services.yggdrasil.enable` on woody).
- Produces: woody's ygg interface serves 443 only; every host lists `cache.kauderwels.ch` first-cache fallback after cache.nixos.org.

- [ ] **Step 1: Apply both edits.**

- [ ] **Step 2: Eval checks**

  ```bash
  nix eval --json .#nixosConfigurations.lenny.config.nix.settings.substituters   # contains cache.kauderwels.ch
  nix eval --json .#nixosConfigurations.woody.config.networking.firewall.interfaces."ygg".allowedTCPPorts   # [443]
  nix eval .#nixosConfigurations.sid.config.services.harmonia.cache.enable   # error attr missing (sid unmapped) = fine
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add modules/common/update.nix modules/harmonia.nix
  git commit -m "cache: restore kauderwels.ch substituter, 443-only on ygg iface"
  ```

### Task 7: Full-fleet eval sweep

**Files:** none (verification only)

- [ ] **Step 1: Eval every x86 host toplevel (runs green with `ygg = null` everywhere)**

  ```bash
  for h in lenny rex sid woody zurg pricklepants buzz jessie mrpotatohead bootstrap bootstrap-impermanent; do
    nix eval ".#nixosConfigurations.$h.config.system.build.toplevel.drvPath" >/dev/null && echo "OK $h" || echo "FAIL $h";
  done
  ```

  Expected: `OK` ×11 (slinky skipped, aarch64).
- [ ] **Step 2: Fix any regressions, then final commit if any fix was needed.**

### Task 8: Harvest + fill (USER action — pointer only)

**Files:**
- Modify: `global/constants.nix` (the Task 1 comment points here)

- [ ] **Step 1: (user) per host:** ssh in, `yggdrasilctl getSelf` → take `Address` + `box_pub_key`, fill `host.<name>.ygg`/`.yggPub`, delete `ygg = null` placeholders.
- [ ] **Step 2: registrar:** AAAA `cache.kauderwels.ch` → woody's ygg address.
- [ ] **Step 3: re-run the Task 7 sweep, then**
  `nix eval --json '.#nixosConfigurations.lenny.config.nix.buildMachines' | jq length` (expect 10 on fleet hosts; 5 where `ygg` still null), and a manual backup-path proof: `nix store ping --store https://cache.kauderwels.ch`.

---

## Self-review checklist (filled during authoring)

- Spec coverage: overlay module (T2), membership (T3), builders primary+secondary+identity fix (T4), knownHosts (T5), cache URL + 443-only (T6), security pins (T2 AllowedPublicKeys, T6 firewall), harvest/AAAA (T8). All spec sections mapped.
- Pre-harvest eval-green requirement enforced by T2/T4/T5/T7 expected outputs.
- Open risk: `pin` semantics of `AllowedPublicKeys` on the deployed yggdrasil version (0.5/0.6 differences) — evaluated on-host in T8, not via eval.
