# dendritic: home-manager class aspect "accounts" (ADR 0014). Consumed via
# inputs.self.modules.homeManager.accounts by the standalone homeConfigurations
# (modules/nix/home-configurations.nix) and the per-host wiring (rex/lenny).
_: {
  flake.modules.homeManager.accounts = _: {
    accounts.email = {
      accounts.rwth = {
        address = "jerome.bergmann@rwth-aachen.de";
        userName = "jb427270@rwth-aachen.de";
        realName = "Jerome Bergmann";
        signature.text = ''
          Jerome Bergmann
        '';
        imap = {
          host = "owa.rwth-aachen.de";
          port = 993;
          tls.enable = true;
        };
        smtp = {
          host = "owa.rwth-aachen.de";
          port = 587;
          tls.enable = true;
          tls.useStartTls = true;
        };
        thunderbird = {
          enable = true;
          profiles = [ "rwth" ];
        };
      };
      accounts.gmail-privat = {
        primary = true;
        address = "bergmann.jerome@gmail.com";
        userName = "bergmann.jerome@gmail.com";
        realName = "Jerome Bergmann";
        signature.text = ''
          Jerome Bergmann
        '';
        imap = {
          host = "gmail.com";
          port = 993;
          tls.enable = true;
        };
        smtp = {
          host = "gmail.com";
          port = 587;
          tls.enable = true;
          tls.useStartTls = true;
        };
        thunderbird = {
          enable = true;
          profiles = [ "rwth" ];
        };
      };
    };
  };
}
