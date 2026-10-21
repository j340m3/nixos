# Shared ACME setup. Certificates are issued per service, so every module that
# terminates TLS declares its own cert and imports this for the defaults.
{
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "jerome.bergmann@posteo.de";
      webroot = "/var/lib/acme/acme-challenge/";
    };
  };
}
