# dendritic: the default feature set every host gets (ADR 0014). Hosts
# import this aspect; it imports the feature aspects.
{ inputs, ... }: {
  flake.modules.nixos.system-default = {
    imports =
      with inputs.self.modules.nixos;
      [ donquezz ]
      ++ [
        php84-patch # remove when nixos-unstable#php84 >= 8.4.27 (php2shell)
        update
        upgrade-health
        ssh
        ssh-identities
        reticulum
        locale
        sops
        rate-limiting-avoidance
        zram
        domain
        distributed-builds
        mem
        ulimit
        peerpatrol
        agent-md
        home-manager
      ];
    # these two were direct settings of the former _common aggregator
    services.reticulum.enable = true;
    # radicle-node is marked insecure in nixpkgs (unencrypted node traffic)
    nixpkgs.config.permittedInsecurePackages = [ "radicle-node-1.10.3" ];
  };
}
