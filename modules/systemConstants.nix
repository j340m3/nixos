{
  flake.modules.generic.systemConstants =
    { lib, ... }:
    {
      options.systemConstants = lib.mkOption {
        type = lib.types.attrsOf lib.types.unspecified;
        default = { };
      };

      config.systemConstants = {
        nebula.cidr = "10.0.0.0/24";
        domain = "kauderwels.ch";
      };
    };
}
