{ lib, pkgsUnstable, ... }:

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
    package = pkgsUnstable.prowlarr;
    settings.auth = arrAuth;
  };
  services.radarr = {
    enable = true;
    package = pkgsUnstable.radarr;
    settings.auth = arrAuth;
  };
  services.sonarr = {
    enable = true;
    package = pkgsUnstable.sonarr;
    settings.auth = arrAuth;
  };
  services.lidarr = {
    enable = true;
    package = pkgsUnstable.lidarr;
    settings.auth = arrAuth;
  };

  # ── Downloaders ──────────────────────────────────────────────────────────
  services.sabnzbd = {
    enable = true;
    package = pkgsUnstable.sabnzbd;
  };
  # systemd.services.sabnzbd.vpnConfinement = {
  #   enable = true;
  #   vpnNamespace = "wg";
  # };

  services.qbittorrent = {
    enable = true;
    package = pkgsUnstable.qbittorrent-nox;
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
  # systemd.services.qbittorrent.vpnConfinement = {
  #   enable = true;
  #   vpnNamespace = "wg";
  # };

  # ── Plex ─────────────────────────────────────────────────────────────────
  users.users.plex.extraGroups = [
    "render"
    "video"
  ];

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

  # ── Jellyfin ─────────────────────────────────────────────────────────────
  # Intel VA-API transcoding via /dev/dri/renderD128.
  users.users.jellyfin.extraGroups = [
    "render"
    "video"
  ];
  services.jellyfin = {
    enable = true;
    package = pkgsUnstable.jellyfin;
  };
  systemd.services.jellyfin = {
    after = [ "mnt-nas-media.automount" ];
    wants = [ "mnt-nas-media.automount" ];
  };

  # ── Audiobookshelf ───────────────────────────────────────────────────────
  services.audiobookshelf = {
    enable = true;
    port = 13378;
    host = "0.0.0.0";
  };
}
