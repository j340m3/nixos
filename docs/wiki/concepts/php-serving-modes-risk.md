# PHP serving modes under php2shell risk

Which PHP serving configuration is exploitable by CVE-2026-109618/-109619,
which config levers map to which attack path, and what PHP this repo actually
runs. Facts and URLs live in [S1](../sources/php2shell-advisory.md); the
Nextcloud module option facts in [S2](../sources/nixpkgs-nextcloud-module.md).
"Nix-verified" below means checked against nixpkgs `nixos-unstable` @
`55bfb4d7437bd4e09ab7cba58a43bd68eb310044` (the repo's locked rev, Nix 2026-10-22).

Sources: [S1](../sources/php2shell-advisory.md) (advisory facts, IoCs, nixpkgs status), [S2](../sources/nixpkgs-nextcloud-module.md) (services.nextcloud option shape).

## Serving mode → exploitability

From the advisories as tabulated in [S1](../sources/php2shell-advisory.md):

| setup | CVE-…618 (OOM corruption) | CVE-…619 (stale global state) | why |
|---|---|---|---|
| Apache mod_php | RCE confirmed | RCE confirmed | shutdown runs unconditionally even after a failed request startup; exploit fires *before any application code*; .htaccess/php_value is an extra early-config consumer |
| PHP-FPM behind nginx/Apache/Caddy | susceptible by source analysis; **no demonstrated full exploit for this CVE** (the failed-startup path kills the worker instead of running shutdown) | RCE confirmed (session-lifecycle path, application-dependent) | pool `PHP_VALUE`/`PHP_ADMIN_VALUE` passthrough from the frontend is a possible consumer for early-config INI diagnostics |
| php-cgi | affected (official list) | affected | |
| FrankenPHP | likely (analogous to mod_php) | likely (no default early consumer established) | |
| LiteSpeed LSAPI | likely / app-dependent | candidate | models FPM |
| CLI | not covered by the advisories | not covered | same interpreter, gets upgraded anyway |

Practical takeaway for this era: **mod_php = assume RCE now; FPM = RCE via
the session-upload-progress path regardless of what the application does**,
the OOM path needs an additional trigger but the "all default limits"
amplification applies to both ([S1](../sources/php2shell-advisory.md)).

## Attack path → config lever

Both flaws are memory-safety bugs; config levers only narrow attack paths,
and "no complete mitigations, patching is the only safe choice"
([S1](../sources/php2shell-advisory.md), php.net).

| attack path | lever | notes |
|---|---|---|
| CVE-…618 OOM amplification | `memory_limit=-1` (php.ini/FPM `php_admin_value`, Apache config) | removes the predictable per-request budget the exploit lever rides on; *incomplete* (mmap failures can still `longjmp()`); trades in evaluation-RCE freedom for memory-exhaustion DoS risk |
| CVE-…618 body amplification | low `post_max_size`; `upload_max_filesize < post_max_size`; proxy-level limits that apply *even without a usable Content-Length* | declared-length gates don't catch chunked/lengthless bodies |
| CVE-…619 producer (OOM/fatals) | keep memory envelope sane, fix attacker-reachable fatals, `pm.max_requests=1` | same-worker reuse of stale state is a prerequisite; `pm.max_requests=1` trades perf for safety |
| CVE-…619 consumer: session upload progress | `session.upload_progress.enabled = 0`, set where it applies **before request parsing** (php.ini / FPM pool config / server config), never `ini_set()` | default-on in PHP even when the application never calls `session_start()`; keep it off post-patch too |
| CVE-…619 consumer: early-config INI diagnostics | no per-request INI from the frontend (no `PHP_VALUE`/`PHP_ADMIN_VALUE` in fastcgi params; beware `.htaccess` php_value on Apache); no invalid/deprecated INI keys | the "INI diagnostics" consumer needs a *warning during config application*, i.e. a key PHP doesn't recognize |
| producer “8.5 style” | `fatal_error_backtraces = 0` (PHP 8.5) | strongest producer lives in 8.5's backtrace snapshots |

Also not-a-mitigation: WAF rules are defense-in-depth only, and one of the two
(via server-side config paths per [S1](../sources/php2shell-advisory.md)) is
"largely outside the reach of any web application firewall" — recall the
leaked-CVE era got CVSS 10.0 claims before the real 9.2 dropped.

## This repo's PHP, nix-verified 2026-10-22

Only two services consume PHP; everything else in the fleet has no PHP.

| host | service | php interpreter at the locked rev | file |
|---|---|---|---|
| mrpotatohead | `services.nextcloud` (nextcloud35 v35.0.1) | **php84 = 8.4.26** — NixOS nextcloud module default `phpPackage = php84`; repo sets `maxUploadSize = "1G"` (so this pool's `memory_limit`/`post_max_size` are 1G — a full-portion CVE-…618 amplification budget) | `modules/services/nextcloud.nix` |
| woody | `services.zabbixWeb` (zabbix74.web) | **8.4.26** — generic `services.phpfpm.pools.zabbix` defaults `phpPackage = pkgs.php` = 8.4.26; the zabbix module hard-sets its pool ini (`memory_limit = 128M`, `post_max_size = 16M`, ...) | `modules/hosts/woody/configuration.nix` |

Flake pin (from `flake.lock`, node `nixpkgs_8`, root's `nixpkgs` input):
`nixos-unstable` @ `55bfb4d7437bd4e09ab7cba58a43bd68eb310044`, locked
2026-10-14 05:35 UTC — php **8.3.35 / 8.4.26 / 8.5.11** there =
the last vulnerable point releases ([S1](../sources/php2shell-advisory.md)
nixpkgs section). The second nixpkgs input `nixpkgs-master` (@ 2026-10-17)
is also pre-fix; it only feeds `pkgsUnstable` for lenny. Both need the same
treatment when updating.

### What to do (when the channel carries the fix)

1. `git grep -n "c53532a"` on the nixpkgs commit is not a thing branches
   survive; just verify the *result*: `nix flake update nixpkgs
   nixpkgs-master`, then read the new rev out of `flake.lock` (node your
   root `nixpkgs` follows — **`nixpkgs_8` in this lock, not `nodes.nixpkgs`),
   and `nix eval github:NixOS/nixpkgs/<rev>#php84.version` → want ≥ 8.4.27
   ([S1](../sources/php2shell-advisory.md)).
2. `nixos-rebuild switch` mrpotatohead and woody: the switch restarts the
   changed `phpfpm-nextcloud` / `phpfpm-zabbix` units — running workers map
   the old code until then
   ([S1](../sources/php2shell-advisory.md), "version check (host)").
3. Optional hardening, nix-style:
   - nextcloud: `services.nextcloud.phpOptions."session.upload_progress.enabled" = "0"`
     (verified additive attrset option; survives the auto-injection of
     `[S2](../sources/nixpkgs-nextcloud-module.md)`, and keep `php-v` check
     in the deploy pipeline).
   - zabbix/other php-fpm pools: same ini but the zabbix module composes its
     pool `phpOptions` as a *string*; appending to it without clobbering the
     required ini (`memory_limit`, `post_max_size`, …) has to be done by
     string concat — evaluate before acting.
4. Hunt the log horizon back to **2026-10-17** — first in-the-wild attempt
   (AWS MadPot, IP `103.216.220.92`) is 4 days before disclosure
   ([S1](../sources/php2shell-advisory.md)): nginx/nextcloud access logs on
   mrpotatohead for the UA/boundary/IoC list, and `php-fpm` error logs for
   memory-limit fatals right after multipart POSTs. mrpotatohead already
   runs `auditd` execve rules, so a compromised worker leaves exec traces in
   its audit log.

## Not in this repo's exposure, but related

- Nextcloud's `maxUploadSize = 1G` sets `memory_limit = 1G` `post_max_size = 1G`
  ([S2](../sources/nixpkgs-nextcloud-module.md)) — the official partial
  mitigation would want `memory_limit=-1` *plus* a hard per-worker cap
  (e.g. `systemd.services."phpfpm-nextcloud".serviceConfig.MemoryMax` /
  cgroup budget) if you take that lever; one knob without the other just
  moves the DoS risk around.
- The zabbix pool has small limits already (128M), so CVE-…618's default-limit
  amplification doesn't reach it; CVE-…619's session-upload-progress consumer
  is the live concern there until `session.upload_progress.enabled = 0` lands.

## Open uncertainties

- **php82 status**, the nailed-down fixed-nextcloud state, the exact
  endpoint-level `nix` upgrade order (lock node ambiguity!) — none of these
  are settled by this page; see [S1](../sources/php2shell-advisory.md)'s
  nixpkgs section for what is checked vs unverified.
- FrankenPHP update PR was open (not merged) when researched 2026-10-22 —
  this repo doesn't use it, so no action here.
