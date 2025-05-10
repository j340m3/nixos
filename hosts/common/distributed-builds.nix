{ pkgs, ... }:
{
  nix.distributedBuilds = true;
  #nix.settings.builders-use-substitutes = true;

  nix.buildMachines = [
    {
      hostName = "builder";
      #sshUser = "remotebuild";
      #sshKey = "/root/.ssh/remotebuild";
      system = pkgs.stdenv.hostPlatform.system;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "big-parallel" "kvm" "benchmark" ];
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