# Architecture Decision Records

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [0000](0000-update-independence-with-opportunistic-cooperation.md) | Update independence with opportunistic cooperation | accepted (guiding principle) | 2024-12-18 |
| [0001](0001-single-flake-auto-discovered-hosts.md) | Auto-discovered host folders in a single flake | accepted | 2025-07-08 |
| [0002](0002-flake-parts-per-system-outputs.md) | flake-parts for perSystem outputs | accepted | 2026-10-14 |
| [0003](0003-floating-lock-hourly-autoupgrade.md) | Push-to-GitHub delivery with hourly autoUpgrade and floating inputs | accepted | 2024-12-18 / 2025-04-15 |
| [0004](0004-sops-nix-per-host-secrets.md) | sops-nix with per-host secrets files | accepted | 2025-04-01 |
| [0005](0005-nebula-overlay-mesh.md) | Nebula mesh as the overlay VPN | accepted | 2025-04-15 |
| [0006](0006-identity-keys-pubs-plaintext-privs-sops.md) | Identity keys: pubs plaintext, privs in sops | accepted | 2026-10-05 |
| [0007](0007-upgrade-health-auto-rollback.md) | Upgrade-health auto-rollback on headless hosts | accepted | 2026-10-03 |
| [0008](0008-wireguard-peers-plaintext-json.md) | WireGuard peers driven by committed plaintext JSON | accepted | 2026-10-14 |
| [0009](0009-disko-bootstrap-images.md) | Disko bootstrap images incl. impermanence variant | accepted | ~2025 |
| [0010](0010-eval-only-per-host-checks.md) | Eval-only per-host flake checks as the fast CI gate | accepted | 2026-10 |
| [0011](0011-split-hosts-graphical-headless.md) | Split hosts/ into graphical and headless classes | accepted | 2025-10-07 |

All ADRs were backfilled on 2026-10-15 from existing code and
docs; dates are the original decision/implementation dates from git history
where known. Decisions are numbered in review order, not chronological order;
ADR-0000 is the umbrella principle and is placed first.
