# Carrier for the reticulum option tree (same pattern as mesh-ports):
# declared for every host via the mkNixos factory (modules/nix/lib.nix) so
# cross-aspect reach-ins (remote-builder.nix registers identityReaders)
# cannot break hosts that do not import the reticulum aspect (zurg,
# pre-2026-11-11).
_: {
  flake.modules.nixos.reticulum-opts =
    { lib, ... }:
    {
      options.services.reticulum = {
        enable = lib.mkEnableOption "Reticulum";

        # Non-root rnsh listeners need to read the identity and rendered RNS
        # config; group "reticulum" grants exactly that.
        identityReaders = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Users added to the `reticulum` group: can read the decoded fleet
            identity (/run/reticulum/identity) and the rendered
            shared-instance config (/run/reticulum/config). No write access.
            The borg listener is deliberately OUTSIDE this group (audit F3):
            it reads its own identity (sops reticulum/borg_identity) via
            group `rnsh-borg`, so the two listener accounts cannot read —
            and thus impersonate — each other.
          '';
        };

        rnshBorg = {
          enable = lib.mkEnableOption ''
            a second rnsh listener (separate identity, sops key
            `reticulum/borg_identity`) running `borg serve` as the borg user
            instead of exposing the root nix daemon to backup traffic
          '';

          repoPath = lib.mkOption {
            type = lib.types.path;
            default = "/var/lib/borgbackup";
            # mirrors the sshd accept side: clients cannot escape this tree
            description = "Directory the borg listener is restricted to.";
          };

          allowIdentities = lib.mkOption {
            type = lib.types.listOf (lib.types.strMatching "[0-9a-f]{32}");
            default = [ ];
            description = "RNS identity hashes permitted as rnsh-borg clients.";
          };
        };
      };
    };
}
