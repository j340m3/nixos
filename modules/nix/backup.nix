# Carrier for the backup-path collector (improvement session 2026-11-12):
# every host gets the option via lib.mkNixos (modules/nix/lib.nix), so
# feature modules can contribute application-specific backup paths.
# Consumer: modules/services/backup-client.nix (the auto-homes borg client
# aspect), which appends the collected list to the auto-discovered homes.
_: {
  flake.modules.nixos.backup-opts = { lib, ... }: {
    options.backup.paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Application-specific paths this host wants backed up, collected
        from the feature modules and appended to the auto-discovered user
        homes by modules/services/backup-client.nix. Contribute
        application-wise paths (state dirs, config snippets), never a
        blind /etc catch-all.
      '';
    };
  };
}
