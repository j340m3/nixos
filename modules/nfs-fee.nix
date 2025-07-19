{
  config,
  lib,
  pkgs,
  ...
} : {
  /* fileSystems."/export/feeshare" = {
    device = "/mnt/feeshare";
    options = [ "bind" ];
  }; */

  services.nfs.server.exports = ''
    /export         192.168.178.0/24(rw,fsid=0,no_subtree_check)
    /export/feeshare  192.168.178.0/24(rw,nohide,insecure,no_subtree_check,all_squash,anonuid=0,anongid=0)
    '';

  services.nfs.server = {
    enable = true;
    # fixed rpc.statd port; for firewall
    lockdPort = 4001;
    mountdPort = 4002;
    statdPort = 4000;
    extraNfsdConfig = '''';
  };
  networking.firewall = {
    enable = true;
      # for NFSv3; view with `rpcinfo -p`
    allowedTCPPorts = [ 111  2049 4000 4001 4002 20048 ];
    allowedUDPPorts = [ 111 2049 4000 4001  4002 20048 ];
  };
}