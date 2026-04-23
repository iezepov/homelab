{ config, pkgs, lib, ... }:

let
  sites = {
    "lab.baddog.ch"             = "http://localhost:8082";
    "paperless.lab.baddog.ch"   = "http://localhost:28981";
    "actual.lab.baddog.ch"      = "http://localhost:5006";
    "uptime.lab.baddog.ch"      = "http://localhost:3001";
    "prowlarr.lab.baddog.ch"    = "http://localhost:9696";
    "radarr.lab.baddog.ch"      = "http://localhost:7878";
    "sonarr.lab.baddog.ch"      = "http://localhost:8989";
    "lidarr.lab.baddog.ch"      = "http://localhost:8686";
    "qbittorrent.lab.baddog.ch" = "http://localhost:8081";
    "sabnzbd.lab.baddog.ch"     = "http://localhost:8080";
    "tautulli.lab.baddog.ch"    = "http://localhost:8181";
    # Proxy to NAS
    "nas.lab.baddog.ch"         = "http://dionysos.bonobo-torino.ts.net:5000";
  };

  mkVhost = _: url: {
    extraConfig = "reverse_proxy ${url}";
  };
in
{
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];

  sops.secrets.cf_api_token = {
    owner = "caddy";
  };

  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
      hash = "sha256-4WF7tIx8d6O/Bd0q9GhMch8lS3nlR5N3Zg4ApA3hrKw=";
    };
    environmentFile = config.sops.secrets.cf_api_token.path;

    globalConfig = ''
      email admin@baddog.ch
      cert_issuer acme {
        dns cloudflare {env.CF_API_TOKEN}
        resolvers 1.1.1.1 8.8.8.8
      }
    '';

    virtualHosts = lib.mapAttrs mkVhost sites;
  };
}
