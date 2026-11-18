# run0 admin capability (improvement session 2026-11-12), stage A of the
# sudo replacement: polkit plus a wheel rule, sudo stays for the burn-in.
# Stage B (a later commit, after the buzz canary) flips
# security.sudo.enable off here, so every host that imports this aspect
# replaces sudo at once.
#
# The rule returns AUTH_ADMIN, never YES: a YES rule would let every process
# running as a wheel user call run0 passwordless — strictly weaker than the
# sudo model it replaces. run0 shares the
# org.freedesktop.systemd1.manage-units polkit action with systemctl, so this
# rule also drops the default auth_admin_keep caching of active (local)
# sessions: authenticate every time, like sudo with timestamp_timeout = 0.
# SSH sessions are inactive sessions and were already auth_admin.
#
# run0 authenticates through pkttyagent (shipped with systemd), so it works
# on a headless host without a desktop polkit agent. Verify
# `run0 nixos-rebuild switch` on buzz before removing sudo.
{
  flake.modules.nixos.run0-admin = {
    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.isInGroup("wheel")) {
          return polkit.Result.AUTH_ADMIN;
        }
      });
    '';
  };
}
