{ self, config, lib, pkgs, ... }: {
  simmich-public-proxy = {
      enable = true;
      immichUrl = "http://10.0.0.3:2283";
      port = 3001;
    };
}