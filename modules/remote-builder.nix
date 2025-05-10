{
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  users.users.remotebuild = {
    isNormalUser = true;
    createHome = false;
    group = "remotebuild";
    openssh.authorizedKeys.keys = [''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINl53KG7Z2l3NSGDSOX5YzmnMzIXbWfnls0J6Hmzcpbv root@pricklepants''];
    #openssh.authorizedKeys.keyFiles = [ ./remotebuild.pub ];
  };

  users.groups.remotebuild = {};

  nix.settings.trusted-users = [ "remotebuild" ];
}