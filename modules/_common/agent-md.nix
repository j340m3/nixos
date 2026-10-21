_:

{
  environment.etc."nixos/AGENT.md".text = ''
    # AGENT.md — read this before touching anything

    **Do not modify, rebuild from, or commit anything inside `/etc/nixos`.**

    `/etc/nixos` is not the source of this system. This machine is a NixOS host
    built from the flake at https://github.com/j340m3/nixos.

    If you operate a coding agent on this host:

    - `/etc/nixos` is leftover scaffolding — treat it as read-only; never edit,
      delete, or build from it.
    - All configuration changes happen in the source repo
      (`https://github.com/j340m3/nixos`), then are rolled out from there.
    - Do not run `nixos-rebuild` locally against auto-upgraded state; changes
      land via the repo first.

    Rebuilding from anything other than the flake repo risks overwriting
    fleet-wide configuration and secrets wiring.
  '';
}
