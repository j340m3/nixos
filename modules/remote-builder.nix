{
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  users.users.remotebuild = {
    isNormalUser = true;
    createHome = false;
    group = "remotebuild";
    openssh.authorizedKeys.keys = [
      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINl53KG7Z2l3NSGDSOX5YzmnMzIXbWfnls0J6Hmzcpbv root@pricklepants''
      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJu52XPMcQve06Z6PeYgW4bLxF+zWrORq3zb2swGeL6F root@rex''
      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILV1ywPe/y2QdwFzwn9cFuTSjxyDxf4VTyq//PO3bQLs root@buzz''
      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIHuH2aKZz3RxX3H5FBFuxFrcyD2hilgJFc3y0jTUbgR root@jessie''
      ];
    #openssh.authorizedKeys.keyFiles = [ ./remotebuild.pub ];
  };

  users.groups.remotebuild = {};

  #nix.settings.trusted-users = [ "remotebuild" ];
  nix = {
    nrBuildUsers = 64;
    settings = {
      trusted-users = [ "remotebuild" ];

      min-free = 10 * 1024 * 1024;
      max-free = 200 * 1024 * 1024;

      max-jobs = "auto";
      cores = 0;
    };
  };

  systemd.services.nix-daemon.serviceConfig = {
    MemoryAccounting = true;
    MemoryMax = "90%";
    OOMScoreAdjust = 500;
  };
}