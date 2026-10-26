{ lib, pkgs, pkgsUnstable, ... }:

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
  # Subtitle manager for Sonarr/Radarr. The module exposes no `settings`
  # option (only enable/port/dataDir), so Bazarr is configured through its
  # own API after first boot -- see AGENTS.md / the homelab-lab skill.
  # pkgs.bazarr is 1.6.x in the stable pin; `pkgsUnstable.bazarr` does not
  # exist, so do not "harmonise" this line with its neighbours.
  services.bazarr = {
    enable = true;
    package = pkgs.bazarr;
  };
  # Request manager for the household (Jellyfin-based). Deliberately NOT
  # pkgsUnstable like its neighbours: seerr 3.2.0 lives in the stable pin and is
  # absent from the unstable pin. openFirewall stays false -- the service is
  # consumed through the Caddy vhost in caddy.nix (and the tailnet, since
  # firewall.trustedInterfaces trusts tailscale0).
  services.seerr = {
    enable = true;
    port = 5055;
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
    # No host-side listener exists on the webui port since qBittorrent moved into
    # the VPN namespace, so this firewall opening serves nothing: peer connections
    # arrive through the ProtonVPN forwarded port inside the namespace, and the UI
    # is reached through Caddy. Left over from the pre-confinement setup.
    openFirewall = false;
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
  # Route all qBittorrent traffic through the ProtonVPN namespace. Without this
  # the client runs on the host network and leaks peer traffic via the home IP.
  # Downloads still work: NFS mounts live in the host namespace, so writes to
  # /mnt/nas use the already-established mount. The web UI stays reachable via
  # the 8081 port mapping declared in vpn.nix.
  systemd.services.qbittorrent.vpnConfinement = {
    enable = true;
    vpnNamespace = "wg";
  };

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
