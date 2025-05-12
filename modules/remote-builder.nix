{
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  users.users.remotebuild = {
    isNormalUser = true;
    createHome = false;
    group = "remotebuild";
    openssh.authorizedKeys.keys = [
      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINl53KG7Z2l3NSGDSOX5YzmnMzIXbWfnls0J6Hmzcpbv root@pricklepants''
      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJu52XPMcQve06Z6PeYgW4bLxF+zWrORq3zb2swGeL6F root@rex''
      ];
    #openssh.authorizedKeys.keyFiles = [ ./remotebuild.pub ];
  };

  users.groups.remotebuild = {};

  nix.settings.trusted-users = [ "remotebuild" ];
}