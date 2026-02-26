{ pkgs, config, ... }:
{
  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true;

  nix.buildMachines = [
    {
      hostName = "builder1";
      #sshUser = "remotebuild";
      #sshKey = "/root/.ssh/remotebuild";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      #system = pkgs.stdenv.hostPlatform.system;
      speedFactor = 10;
      protocol = "ssh-ng";
      supportedFeatures = [
        "nixos-test"
        "big-parallel"
        "kvm"
        "benchmark"
      ];
      maxJobs = 6;
    }
    {
      hostName = "builder2";
      #sshUser = "remotebuild";
      #sshKey = "/root/.ssh/remotebuild";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      #system = pkgs.stdenv.hostPlatform.system;
      speedFactor = 1;
      protocol = "ssh-ng";
      supportedFeatures = [ ];
      maxJobs = 2;
    }
    {
      hostName = "builder3";
      #sshUser = "remotebuild";
      #sshKey = "/root/.ssh/remotebuild";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      #system = pkgs.stdenv.hostPlatform.system;
      speedFactor = 1;
      protocol = "ssh-ng";
      supportedFeatures = [ ];
      maxJobs = 6;
    }
    {
      hostName = "builder4";
      #sshUser = "remotebuild";
      #sshKey = "/root/.ssh/remotebuild";
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      #system = pkgs.stdenv.hostPlatform.system;
      speedFactor = 100;
      protocol = "ssh-ng";
      supportedFeatures = [
        "nixos-test"
        "big-parallel"
        "kvm"
        "benchmark"
      ];
      maxJobs = 20;
    }
  ];
  programs.ssh.extraConfig = ''
    Host builder1
      HostName 10.0.0.3
      Port 42069
      User remotebuild
      IdentitiesOnly yes
      IdentityFile /root/.ssh/remotebuild
    Host builder2
      HostName 10.0.0.7
      Port 42069
      User remotebuild
      IdentitiesOnly yes
      IdentityFile /root/.ssh/remotebuild
    Host builder3
      HostName woody.fritz.box
      Port 42069
      User remotebuild
      IdentitiesOnly yes
      IdentityFile /root/.ssh/remotebuild
    Host builder4
      HostName 10.0.0.10
      Port 42069
      User remotebuild
      IdentitiesOnly yes
      IdentityFile /root/.ssh/remotebuild
  '';

  sops.secrets."remotebuild/key" = {
    sopsFile = ../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
    owner = "root";
    group = "root";
    path = "/root/.ssh/remotebuild";
  };

  sops.secrets."remotebuild/pub" = {
    sopsFile = ../../secrets/hosts/${config.networking.hostName}/secrets.yaml;
    owner = "root";
    group = "root";
    path = "/root/.ssh/remotebuild.pub";
  };
}
