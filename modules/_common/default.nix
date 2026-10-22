{
  imports = [
    ./update.nix
    ./upgradeHealth.nix
    ./ssh.nix
    ./ssh-identities.nix
    ../_reticulum.nix
    ./sops.nix
    ./rate_limiting_avoidance.nix
    ./distributed-builds.nix
    #./lockup.nix
    #./ntp.nix
    ./peerpatrol.nix
    ./agent-md.nix
    ./home-manager.nix
    ../../users/donquezz.nix
  ];

  services.reticulum.enable = true;

  # radicle-node is marked insecure in nixpkgs (unencrypted node traffic)
  nixpkgs.config.permittedInsecurePackages = [
    "radicle-node-1.10.3"
  ];
}
