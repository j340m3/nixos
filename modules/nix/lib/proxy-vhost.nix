# nginx reverse-proxy virtual host helper (flake.lib): the fleet's TLS vhosts
# all share the same skeleton — forceSSL + an ACME binding + a single "/"
# location proxying to a local service. Parameters cover the observed variation:
#
#   acme binding      enableACME (default) or useACMEHost (DNS-01 certs issued
#                     elsewhere, e.g. the acmeDns01 helper / the nextcloud main
#                     vhost's HTTP-01 cert)
#   proxyPass         full URL; callers build it, usually
#                     "http://127.0.0.1:${toString <service>.port}"
#   websockets        proxyWebsockets (default true; vaultwarden opts out)
#   extraConfig       location-level directives (client_max_body_size,
#                     proxy_set_header …). NOTE (nginx inheritance): a location
#                     with any proxy_set_header of its own stops inheriting the
#                     server-level ones — that is why headers live here.
#   wellKnownRoot     adds locations."/.well-known/".root = "/var/lib/acme/
#                     acme-challenge/" (HTTP-01 challenge routing, nextcloud
#                     files vhost).
{
  inputs, lib, ...
}:
{
  flake.lib.proxyVhost =
    {
      domain,
      proxyPass,
      useACMEHost ? false,
      websockets ? true,
      extraConfig ? "",
      wellKnownRoot ? false,
    }:
    lib.recursiveUpdate
      (lib.recursiveUpdate
        {
          forceSSL = true;
          locations."/" = {
            inherit proxyPass;
            proxyWebsockets = websockets;
            inherit extraConfig;
          };
        }
        (if useACMEHost then { useACMEHost = domain; } else { enableACME = true; }))
      (lib.optionalAttrs wellKnownRoot {
        locations."/.well-known/".root = "/var/lib/acme/acme-challenge/";
      });
}
