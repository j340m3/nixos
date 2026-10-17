---
title: Smallest bootable NixOS ISO (~91 MiB) — siraben gist
url: https://gist.github.com/siraben/a8fce9912891d85e1ec3cf74081ba4f6
kind: primary
accessed: 2026-10-16
---

# siraben — smallest bootable NixOS ISO (~91 MiB)

Continuation of `natkr-nixos-but-smol` (183 MiB → 91 MiB). Boots to an
autologin root shell; every step verified booting in QEMU (serial + VGA).
Targets a **live ISO**, not an installed disk — read the levers, not the
`system.stateVersion = "26.05"` image assumptions.

## Result

- ISO 458 MiB (stock minimal) → 183 MiB (natkr) → **91 MiB**. ~half of natkr.
- Asked closure ≈232 MiB → ISO 91 MiB after compression.

## Levers that moved the needle (each verified)

1. **xz everything** — `isoImage.squashfsCompression = "xz -Xdict-size 100% -Xbcj x86"`,
   xz initrd (`boot.initrd.compressor = "xz"`, args `-9 -e --check=crc32`).
   *Gotcha:* kernel built-in xz initramfs decoder cannot read multi-threaded
   (`-T0`) streams — silently truncates, panics at root mount.
2. **Cheap closure trims** — drop sudo, nano (drags `file`/libmagic), empty the
   ~13 MiB udev `hwdb.bin`.
3. **Slim systemd via overlay** (not just `systemd.package`) — ~30 `withXxx = false`
   flags (tpm2, repart, importd, homed, networkd, oomd, coredump, …). Overlay
   matters so libsystemd consumers (dbus-broker, hostname, util-linux) link the
   slim build instead of pulling a second full ~63 MiB systemd. Slim systemd ≈ 35 MiB.
4. **Drop pure-$PATH tools** nothing else references: bind `host`, ping, curl, hostname.
5. **Trim initrd modules** to what the VM needs; iso-image/etc-overlay add
   squashfs/iso9660/overlay/erofs.
6. **Smaller kernel** via XZ self-compression (`KERNEL_XZ`, `KERNEL_ZSTD = no`).
7. **Drop `switch-to-configuration`** (`system.switch.enable = false`) — immutable
   image; drags ~10 MiB C++ stdlib.
8. **util-linuxMinimal overlay** — full build (14 MiB lib + 9.8 MiB bin + 5.9 MiB
   sqlite) referenced directly by agetty/mount, so only an overlay removes it.
9. Networking off (`networking.firewall.enable/permit`), drop iproute2/elfutils.
10. `coreutils-full` → `coreutils`, C.UTF-8 locale (built into glibc → no locale archive).
11. dbus → slim systemd (drops separate `systemd-minimal` ≈21 MiB); `x11Support = false`.
12. `withOpenSSL=false`/`withLibarchive=false`; `withVConsole=false` (drops kbd).
13. Disable lastlog (drops sqlite); trim optional $PATH tools (gnutar/bzip2/cpio/…).
14. `system.etc.overlay.enable = true`, `services.userborn.enable = true` replace perl;
    `nix.enable = false`; `systemd.services.register-nix-paths = mkForce {}`.

## Where the remaining bytes go (≈232 MiB closure → 91 MiB ISO)

Big irreducibles: **glibc 35**, **slim systemd 35**, **kernel bzImage + initrd
≈32 combined**, C++ stdlib pulled by `nixos-init` 10, two util-linux builds, bash,
and `linux-headers-static` (leaked by the suid wrappers kept for `unix_chkpwd`).

## Deliberately kept

- `security.wrappers` — `pam_unix` needs `unix_chkpwd`; removing it makes login
  loop with "Authentication service cannot retrieve authentication info".
- systemd-in-initrd — required by `system.etc.overlay`, which is what lets you drop perl.

## Caveats

- This is off-label: an ISO built to boot, not a general-purpose host.
- Further wins need a custom minimal kernel config (high risk) or replacing glibc.
