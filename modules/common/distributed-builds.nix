{ pkgs, ... }:
{
  nix.distributedBuilds = true;
  nix.settings.builders-use-substitutes = true;

  nix.buildMachines = [
    {
      hostName = "builder";
      #sshUser = "remotebuild";
      #sshKey = "/root/.ssh/remotebuild";
      systems = [ "x86_64-linux" "aarch64-linux" ];
      #system = pkgs.stdenv.hostPlatform.system;
      speedFactor = 100;
      protocol = "ssh-ng";
      supportedFeatures = [ "nixos-test" "big-parallel" "kvm" "benchmark" ];
      max-jobs = 6;
    }
  ];
  programs.ssh.extraConfig = ''
  Host builder
    HostName 10.0.0.3
    Port 42069
    User remotebuild
    IdentitiesOnly yes
    IdentityFile /root/.ssh/remotebuild
  '';
}