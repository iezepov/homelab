{ config, pkgs, lib, ... }:

let
  sites = {
    "lab.baddog.ch"             = "http://localhost:8082";
    "paperless.lab.baddog.ch"   = "http://localhost:28981";
    "actual.lab.baddog.ch"      = "http://localhost:5006";
    "uptime.lab.baddog.ch"      = "http://localhost:3001";
    "monica.lab.baddog.ch"      = "http://localhost:8083";
    "prowlarr.lab.baddog.ch"    = "http://localhost:9696";
    "radarr.lab.baddog.ch"      = "http://localhost:7878";
    "sonarr.lab.baddog.ch"      = "http://localhost:8989";
    "lidarr.lab.baddog.ch"      = "http://localhost:8686";
    "qbittorrent.lab.baddog.ch" = "http://192.168.15.1:8081";
    "sabnzbd.lab.baddog.ch"     = "http://localhost:8080";
    "tautulli.lab.baddog.ch"    = "http://localhost:8181";
    "jellyfin.lab.baddog.ch"    = "http://localhost:8096";
    # Proxy to NAS
    "nas.lab.baddog.ch"         = "http://192.168.1.117:5000";
    # Obsidian LiveSync backend (CouchDB, localhost-bound); tailnet only
    "obsidian.lab.baddog.ch"    = "http://127.0.0.1:5984";
  };

  mkVhost = _: url: {
    extraConfig = "reverse_proxy ${url}";
  };

  # Tailnet-only vhost. Lab's :443 is reachable from the LAN, and a LAN client can
  # spoof the Host/SNI to reach any vhost in this file -- for the agent's WebUI that
  # is a remote-code-execution path, so the client's network is checked, not just the
  # name. Tailscale clients arrive from 100.64.0.0/10; everyone else gets a 404.
  mkVhostTailnetOnly = _: url: {
    extraConfig = ''
      @tailnet remote_ip 100.64.0.0/10
      handle @tailnet {
        reverse_proxy ${url}
      }
      handle {
        respond "Not found" 404
      }
    '';
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
      hash = "sha256-xRJ5evsAJ2akg47j3Bt6YDXJOgX88B/rKNP50KSVyNY=";
    };
    environmentFile = config.sops.secrets.cf_api_token.path;

    globalConfig = ''
      email admin@baddog.ch
      cert_issuer acme {
        dns cloudflare {env.CF_API_TOKEN}
        resolvers 1.1.1.1 8.8.8.8
      }
    '';

    # Hermes WebUI on the hermes VM (the agent host), tailnet-gated.
    virtualHosts = lib.mapAttrs mkVhost sites // {
      "hermes.lab.baddog.ch" = mkVhostTailnetOnly "hermes.lab.baddog.ch" "http://100.117.67.0:8787";
    };
  };
}
