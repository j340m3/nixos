{
  imports = [
    ../_reticulum.nix
    #./lockup.nix
    #./ntp.nix
    ./agent-md.nix
    ../../users/donquezz.nix
  ];

  services.reticulum.enable = true;

  # radicle-node is marked insecure in nixpkgs (unencrypted node traffic)
  nixpkgs.config.permittedInsecurePackages = [
    "radicle-node-1.10.3"
  ];
}
