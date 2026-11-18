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
let
  # Application-wise hardening (improvement session 2026-11-12): every vhost
  # this helper builds inherits the headers at server level, so a new vhost
  # is hardened by construction. nginx inheritance quirk: a location that
  # sets its own add_header drops these — override deliberately there, not
  # by adding a duplicate header. HSTS stays scoped to the vhost's hostname
  # (no includeSubDomains) so this vhost's policy cannot force an unrelated
  # sibling subdomain into HTTPS.
  securityHeaders = ''
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
    add_header Strict-Transport-Security "max-age=31536000" always;
  '';
in
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
          extraConfig = securityHeaders;
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
