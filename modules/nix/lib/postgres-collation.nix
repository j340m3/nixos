# Rebuild index-backed collations after a glibc bump (flake.lib helper, ADR
# 0015 deferred queue). flake.lock is not committed, so a glibc bump can
# arrive with any nixpkgs update and postgres then warns about a collation
# version mismatch on every connection (and nextcloud's occ fails the same
# way). Reindex each connectable database once, then record the new version.
# Best-effort: never keep postgres from starting. The check itself is a
# cheap select, so running it on every postgres start is free.
#
#   imports = [ inputs.self.lib.postgresCollation ]
#
# This is the general form of the per-database special case that used to
# live in nextcloud.nix's nextcloud-setup postStart.
{ lib, ... }:
{
  flake.lib.postgresCollation =
    { config, pkgs, lib, ... }:
    {
      systemd.services.postgresql.postStart = lib.mkAfter ''
        psql=${config.services.postgresql.package}/bin/psql
        "$psql" -tAc "select datname from pg_database where datallowconn and datcollversion is not null and datcollversion <> '${pkgs.glibc.version}'" |
          while IFS= read -r db; do
            [ -n "$db" ] || continue
            if "$psql" -d "$db" -c "REINDEX DATABASE \"$db\";"; then
              "$psql" -d postgres -c "ALTER DATABASE \"$db\" REFRESH COLLATION VERSION;" || true
            fi
          done
        true
      '';
    };
}
