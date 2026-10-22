# dendritic: feature aspects peeled from the former modules/_common
# directory (ADR 0014). Each aspect is a thin wrapper over the parked plain
# module it used to be; absorb the module body here in a follow-up per
# feature. Hosts import this aspect; it imports the feature aspects.
{ inputs, ... }: {
  flake.modules.nixos.system-default = {
    imports =
      with inputs.self.modules.nixos;
      [ ../../users/donquezz.nix ]
      ++ [
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
