{...}:
let 
  domainName = "kauderwels.ch";
in
{
  security.acme = {
      acceptTerms = true;
      defaults = {
        email = "jerome.bergmann@posteo.de";
        dnsProvider = "ionos";
        # location of your CLOUDFLARE_DNS_API_TOKEN=[value]
        # https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#EnvironmentFile=
        environmentFile = "/var/lib/acme/api_key";
      };
      certs.${domainName}.extraDomainNames = [
        "vaultwarden.kauderwels.ch"
        "nextcloud.kauderwels.ch"
      ];
    };
}