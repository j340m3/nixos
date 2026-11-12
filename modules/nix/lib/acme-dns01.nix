# IONOS DNS-01 ACME certificate body (flake.lib helper, ADR 0015 deferred
# queue). The fleet's public hosts terminate TLS on vhosts but have no inbound
# port for HTTP-01, so their certs are DNS-01-issued with the IONOS API key.
# The key deploys once per host via harmonia's service-scoped sops file
# (harmonia.nix), so every consumer lives on a host that imports the harmonia
# aspect; the secret path is passed in explicitly because flake.lib is pure.
# The router serves a stale NXDOMAIN for challenge records, hence the public
# 1.1.1.1 resolver instead of the local one.
{ lib, ... }:
{
  flake.lib.acmeDns01 =
    ionosKeyPath: extra:
    {
      dnsProvider = "ionos";
      dnsResolver = "1.1.1.1:53";
      webroot = lib.mkForce null;
      credentialFiles.IONOS_API_KEY_FILE = ionosKeyPath;
    }
    // extra;
}
