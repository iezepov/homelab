{ config, ... }:

{
  # ── Monica CRM ────────────────────────────────────────────────────────────
  sops.secrets.monica_appkey = {
    owner = "monica";
    mode = "0400";
  };

  services.monica = {
    enable = true;
    hostname = "monica.lab.baddog.ch";
    appURL = "https://monica.lab.baddog.ch";
    appKeyFile = config.sops.secrets.monica_appkey.path;
  };

  # Monica ships with its own nginx vhost. Keep it on a local-only port and
  # reverse proxy to it with Caddy (which owns 80/443 and terminates TLS).
  services.nginx.defaultListenAddresses = [ "127.0.0.1" ];
  services.nginx.defaultHTTPListenPort = 8083;
}
