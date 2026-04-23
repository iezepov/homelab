{ lib, ... }:

let
  arrAuth = {
    method = "External";
    required = "DisabledForLocalAddresses";
  };
in
{
  # ── Arr stack ────────────────────────────────────────────────────────────
  services.prowlarr = {
    enable = true;
    settings.auth = arrAuth;
  };
  services.radarr = {
    enable = true;
    settings.auth = arrAuth;
  };
  services.sonarr = {
    enable = true;
    settings.auth = arrAuth;
  };
  services.lidarr = {
    enable = true;
    settings.auth = arrAuth;
  };

  # ── Downloaders ──────────────────────────────────────────────────────────
  services.sabnzbd.enable = true;
  services.qbittorrent = {
    enable = true;
    openFirewall = true; # Needed for seeding
    webuiPort = 8081;
    serverConfig.Preferences = {
      "WebUI\\LocalHostAuth" = false;
      "WebUI\\AuthSubnetWhitelistEnabled" = true;
      "WebUI\\AuthSubnetWhitelist" = "100.64.0.0/10, 192.168.0.0/16, 127.0.0.0/8";
    };
  };

  # ── Plex ─────────────────────────────────────────────────────────────────
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "unrar"
      "plexmediaserver"
      "claude-code"
    ];
  services.plex = {
    enable = true;
    openFirewall = true;
  };
  services.tautulli.enable = true;

  # ── Audiobookshelf ───────────────────────────────────────────────────────
  services.audiobookshelf = {
    enable = true;
    port = 13378;
    host = "0.0.0.0";
  };
}
