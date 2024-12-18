{ ... }: {
  imports = [
    ./hardware-configuration.nix
    
    
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "ubuntu";
  networking.domain = "";
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKv3fhY8KfwN4GFxXpbWLCfNl4ZP+v+C59CIxXhj0SyB jerome@DESKTOP-B7K2FBB'' ];
  system.stateVersion = "23.11";
}
