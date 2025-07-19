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
    /export/feeshare  192.168.178.0/24(rw,crossmnt,sync,no_wdelay,root_squash,insecure,no_subtree_check,fsid=0,anonuid=0,anongid=0)
    '';

  services.nfs.server = {
    enable = true;
    # fixed rpc.statd port; for firewall
    lockdPort = 4001;
    mountdPort = 4002;
    statdPort = 4000;
  };
  networking.firewall = {
    enable = true;
      # for NFSv3; view with `rpcinfo -p`
    allowedTCPPorts = [ 111  2049 4000 4001 4002 20048 ];
    allowedUDPPorts = [ 111 2049 4000 4001  4002 20048 ];
  };

  sevices.nfs = {
    settings = {
      nfsd.udp = true;
      nfsd.rdma = true;
      nfsd.vers3 = false;
      nfsd.vers4 = true;
      nfsd."vers4.0" = false;
      nfsd."vers4.1" = false;
      nfsd."vers4.2" = true;
    };
  };
}