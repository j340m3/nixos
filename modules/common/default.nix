{
  imports = [
    ./update.nix
    ./upgradeHealth.nix
    ./ssh.nix
    ./ssh-identities.nix
    ../reticulum.nix
    ./locale.nix
    ./sops.nix
    ./rate_limiting_avoidance.nix
    ./zram.nix
    ./domain.nix
    ./distributed-builds.nix
    ./mem.nix
    #./lockup.nix
    #./ntp.nix
    ./ulimit.nix
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
