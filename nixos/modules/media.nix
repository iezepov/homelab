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
  systemd.services.sabnzbd.vpnConfinement = {
    enable = true;
    vpnNamespace = "wg";
  };

  services.qbittorrent = {
    enable = true;
    openFirewall = true; # Needed for seeding
    webuiPort = 8081;
    serverConfig.Preferences = {
      # WebUI auth
      "WebUI\\LocalHostAuth" = false;
      "WebUI\\AuthSubnetWhitelistEnabled" = true;
      "WebUI\\AuthSubnetWhitelist" = "100.64.0.0/10, 192.168.0.0/16, 127.0.0.0/8, 192.168.15.0/24";

      # Downloads
      "Downloads\\SavePath" = "/mnt/nas/media/torrents/";
      "Downloads\\TorrentContentLayout" = "Original";
      "Downloads\\PreallocateAll" = true;
      "Downloads\\DeleteTorrentsAsAdded" = true;

      # Connection
      "Connection\\UPnP" = false;
      "Connection\\RandomPort" = false;

      # BitTorrent - privacy/discovery
      "Bittorrent\\DHT" = true;
      "Bittorrent\\PeX" = true;
      "Bittorrent\\LSD" = true;
      "Bittorrent\\AnonymousMode" = false;
      "Bittorrent\\Encryption" = 1; # 0=prefer plaintext, 1=prefer encrypted, 2=require encrypted

      # Seeding limits - disabled
      "Bittorrent\\MaxRatio" = -1;
      "Bittorrent\\MaxSeedingMinutes" = -1;
    };
  };
  systemd.services.qbittorrent.vpnConfinement = {
    enable = true;
    vpnNamespace = "wg";
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
