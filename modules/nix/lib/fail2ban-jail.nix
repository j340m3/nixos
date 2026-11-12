# One fail2ban jail plus its optional filter.d override, as a single unit
# (flake.lib helper, ADR 0015 deferred queue). The skeleton is shared by the
# nextcloud and vaultwarden jails; the jail settings and filter bodies stay
# at the call sites because they differ completely (journal vs syslog
# backend, different regexes and thresholds).
#
# Invariants encoded here (all learned on pricklepants — see
# modules/services/vaultwarden.nix for the full story):
#   - `filter = <name>` makes fail2ban read filter.d/<name>.conf and then
#     filter.d/<name>.local, and the .local overrides the shipped failregex.
#   - the override file must keep the name of the filter it shadows:
#     naming it something else, or pointing filter at a dash name while the
#     file is <name>.local, leaves fail2ban looking for a file that does
#     not exist and it skips the jail with "Found no accessible config
#     files".
#
#   imports = [ (inputs.self.lib.fail2banJail {
#     name = "vaultwarden";
#     settings = { enabled = true; backend = "systemd"; … };
#     filter = ''  # optional; a filter.d/<name>.local override
#       [Definition]
#       failregex = …
#     '';
#   }) ]
{ lib, ... }:
{
  flake.lib.fail2banJail =
    {
      name,
      settings,
      filter ? null,
    }:
    { services.fail2ban.jails.${name}.settings = settings; }
    // lib.optionalAttrs (filter != null) {
      environment.etc."fail2ban/filter.d/${name}.local".text = filter;
    };
}
