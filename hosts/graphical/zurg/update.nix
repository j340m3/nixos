{lib,...}:{
  system.autoUpgrade = {
      enable = true;
      flake = "/etc/nixos";
      #flake = "github:j340m3/nixos";
      #flake = inputs.self.outPath;
      flags = [ 
      # "--update-input" "nixpkgs"
      "--upgrade-all"
      #  "--no-write-lock-file"
      ];
      allowReboot = true;
      dates = lib.mkDefault "*-*-* 0/1:45:00";
      randomizedDelaySec = lib.mkDefault "25min";
      #dates = lib.mkDefault "hourly";
      rebootWindow = {
        lower = lib.mkDefault "22:00";
        upper = "08:00";
    };
  };
}
