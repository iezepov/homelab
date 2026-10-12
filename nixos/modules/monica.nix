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

  # MySQL exists ONLY for Monica (it is the single user database in there; Immich
  # uses Postgres, Paperless/Actual/Kuma/the *arr apps use SQLite). MariaDB's default
  # with no bind-address is to listen on every interface, and /etc/my.cnf had none -
  # so it was answering on the LAN's 0.0.0.0:3306 even though the firewall blocked it.
  # Pin it to loopback: nothing outside this host has any business reaching it.
  services.mysql.settings.mysqld.bind-address = "127.0.0.1";

  # Monica ships with its own nginx vhost. Keep it on a local-only port and
  # reverse proxy to it with Caddy (which owns 80/443 and terminates TLS).
  services.nginx.defaultListenAddresses = [ "127.0.0.1" ];
  services.nginx.defaultHTTPListenPort = 8083;
}
