{config, lib, pkgs, inputs, ...} : 
{
  imports = [
    inputs.impermanence.nixosModules.impermanence
  ];

  environment.persistence."/nix/persist" = {
    hideMounts = true;
    directories = [
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
    ];
    files = [
      "/etc/machine-id"
    ];
    users.jeromeb = {
      directories = [
        "Bilder"
        "Dokumente"
        "Downloads"
        "Musik"
        "Öffentlich"
        "Schreibtisch"
        "Videos"
        "Vorlagen"
        ".local/share/Steam"
        ".local/share/keyrings"
        ".config"
        "VirtualBox VMs"
      ];
    };
  };

  environment.etc."ssh/ssh_host_rsa_key".source
    = "/nix/persist/etc/ssh/ssh_host_rsa_key";
  environment.etc."ssh/ssh_host_rsa_key.pub".source
    = "/nix/persist/etc/ssh/ssh_host_rsa_key.pub";
  environment.etc."ssh/ssh_host_ed25519_key".source
    = "/nix/persist/etc/ssh/ssh_host_ed25519_key";
  environment.etc."ssh/ssh_host_ed25519_key.pub".source
    = "/nix/persist/etc/ssh/ssh_host_ed25519_key.pub";
  environment.etc."machine-id".source
  = "/nix/persist/etc/machine-id";
  sops.age.sshKeyPaths = [ 
    "/nix/persist/etc/ssh/ssh_host_ed25519_key"
    ];
  #fileSystems."/etc/ssh".neededForBoot = true;
}
