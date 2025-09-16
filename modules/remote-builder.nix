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
      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILNdRpz4JYAfntx0frTB78EBZRjWqalvacM63b/7Twu7 root@slinky''
      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICm8t9ZMCyIiA4JS6ltkLHqM0fIS+59Pn5mQiAU9mLqX jeromeb@rex''
      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAoJ35SKgb4qpIy2VI5FZ5qamLh4AMjwFzXWjjJ6TiUK jeromeb@rex''
      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9Jw/TU36ewfgGuKunMD7Jdd1QfX+lDhjFS6XbK513t jeromeb@rex''
      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICJfHMB8d8GxU/C0LjdThoDnNF1RT4qHTwlcDBGO86Vm jeromeb@rex''
      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPTB0wiYamVfYILSOOY9zUNwQUCfEpRCnObe8l89HxGh jeromeb@rex''
      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIARb/kxvi221LEqn7jnikPtDLvX4XQeqqpHmqpT7Qa5o jeromeb@rex''
      ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFBrIG1HMOq+AztxaghvTdVAUiUf8dbNthznXkObGfS2 jeromeb@rex''
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

      max-jobs = 6;
    };
  };

  systemd.services.nix-daemon.serviceConfig = {
    MemoryAccounting = true;
    MemoryMax = "90%";
    OOMScoreAdjust = 500;
  };
}