{
  config,
  pkgs,
  lib,
  ...
}:

let
  arrAuth = {
    method = "External";
    required = "DisabledForLocalAddresses";
  };
in
{
  imports = [ ./hardware-configuration.nix ];

  # ── Sops ──────────────────────────────────────────────────────────────────
  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.age.keyFile = "/home/baddog/.config/sops/age/keys.txt";

  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.loader.grub.devices = [ "/dev/sda" ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/afbdac41-286c-4e79-b479-a571c9e3f29b";
    fsType = "ext4";
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/dd6280da-e49e-4a4e-b183-87e32c7aa314"; }
  ];

  # ── System ────────────────────────────────────────────────────────────────
  networking.hostName = "lab";
  networking.useDHCP = true;
  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.05";

  # ── User ──────────────────────────────────────────────────────────────────
  users.users.baddog = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEOdHCXMy6xXALJZWwHCQj5iUqK/YxLoR3nOq7KjijZE ilya@baddog.ch"
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  # ── SSH ───────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # ── Packages ──────────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    lazygit
    vim
    htop
    curl
    wget
    nfs-utils
  ];
  environment.variables.EDITOR = "vim";

  # ── Tailscale ─────────────────────────────────────────────────────────────
  sops.secrets.tailscale_key = { };
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    authKeyFile = config.sops.secrets.tailscale_key.path;
    extraUpFlags = [ "--ssh" ];
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # ── Caddy ─────────────────────────────────────────────────────────────────
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
    80
    443
  ];
  sops.secrets.cf_api_token = {
    owner = "caddy";
  };

  services.caddy =
    let
      forwardAuth = ''
        forward_auth * http://lighthouse.bonobo-torino.ts.net:31306 {
          uri /api/authz/forward-auth
          copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
        }
      '';

      sites = {
        "lab.baddog.ch" = {
          url = "http://localhost:8082";
          auth = true;
        };
        "plex.lab.baddog.ch" = {
          url = "http://localhost:32400";
          auth = false;
        };
        "actual.lab.baddog.ch" = {
          url = "http://localhost:5006";
          auth = false;
        };
        "uptime.lab.baddog.ch" = {
          url = "http://localhost:3001";
          auth = true;
        };
        "prowlarr.lab.baddog.ch" = {
          url = "http://localhost:9696";
          auth = true;
        };
        "radarr.lab.baddog.ch" = {
          url = "http://localhost:7878";
          auth = true;
        };
        "sonarr.lab.baddog.ch" = {
          url = "http://localhost:8989";
          auth = true;
        };
        "lidarr.lab.baddog.ch" = {
          url = "http://localhost:8686";
          auth = true;
        };
        "qbittorrent.lab.baddog.ch" = {
          url = "http://localhost:8081";
          auth = true;
        };
        "sabnzbd.lab.baddog.ch" = {
          url = "http://localhost:8080";
          auth = true;
        };
        "tautulli.lab.baddog.ch" = {
          url = "http://localhost:8181";
          auth = true;
        };
        # Proxy to NAS machine
        "nas.lab.baddog.ch" = {
          url = "http://dionysos.bonobo-torino.ts.net:5000";
          auth = true;
        };
      };

      mkVhost = site: {
        extraConfig = lib.optionalString site.auth forwardAuth + ''
          reverse_proxy ${site.url}
        '';
      };
    in
    {
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

      virtualHosts = lib.mapAttrs (_: mkVhost) sites;
    };

  # ── Arr stack ─────────────────────────────────────────────────────────────
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

  # ── Downloaders ───────────────────────────────────────────────────────────
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "unrar"
      "plexmediaserver"
    ];
  services.sabnzbd = {
    enable = true;
  };
  services.qbittorrent = {
    enable = true;
    openFirewall = true; # Needed for seeding
    webuiPort = 8081;
    serverConfig.Preferences = {
      "WebUI\\LocalHostAuth" = false; # bypass auth from 127.0.0.1
      "WebUI\\AuthSubnetWhitelistEnabled" = true;
      "WebUI\\AuthSubnetWhitelist" = "100.64.0.0/10, 192.168.0.0/16, 127.0.0.0/8";
    };
  };

  # ── Plex ──────────────────────────────────────────────────────────────────
  services.plex = {
    enable = true;
    openFirewall = true;
  }; # Firewall open for discovery
  services.tautulli = {
    enable = true;
  };

  # ── Audiobookshelf ────────────────────────────────────────────────────────
  services.audiobookshelf = {
    enable = true;
    port = 13378;
    host = "0.0.0.0";
  };

  # ── Actaul Budget ─────────────────────────────────────────────────────────
  services.actual = {
    enable = true;
    settings = {
      port = 5006;
    };
  };

  # ── Uptime Kuma ───────────────────────────────────────────────────────────
  services.uptime-kuma = {
    enable = true;
    settings = {
      PORT = "3001";
    };
  };

  # ── Homepage Dash ─────────────────────────────────────────────────────────
  sops.secrets.homepage_env = {
    # no owner/group — defaults to root:root
    mode = "0400";
    restartUnits = [ "homepage-dashboard.service" ];
  };
  services.homepage-dashboard = {
    enable = true;
    openFirewall = false;
    allowedHosts = "lab.baddog.ch";
    environmentFile = config.sops.secrets.homepage_env.path;

    settings = {
      title = "baddog Homepage";
      theme = "dark";
      color = "stone";
      background = {
        image = "https://images.unsplash.com/photo-1502790671504-542ad42d5189?auto=format&fit=crop&w=2560&q=80";
        brightness = 50;
        opacity = 80;
      };
    };

    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
          cputemp = true;
          uptime = true;
        };
      }
      {
        search = {
          provider = "google";
          target = "_blank";
        };
      }
      {
        datetime = {
          text_size = "xl";
          format.timeStyle = "short";
        };
      }
    ];

    bookmarks = [
      {
        Developer = [
          {
            "My Github" = [
              {
                abbr = "GH";
                href = "https://github.com/iezepov";
              }
            ];
          }
        ];
      }
    ];

    services = [
      {
        Home = [
          {
            "Home Assistant" = {
              icon = "home-assistant.svg";
              href = "http://homeassistant.local:8123";
              description = "Home sweet home";
            };
          }
          {
            Proxmox = {
              icon = "proxmox.svg";
              href = "https://beelab.bonobo-torino.ts.net";
              description = "Proxmox VE";
            };
          }
        ];
      }

      {
        Media = [
          {
            Audiobookshelf = {
              icon = "audiobookshelf.svg";
              href = "https://audiobookshelf.baddog.ch";
              description = "Audiobooks";
              widget = {
                type = "audiobookshelf";
                url = "http://localhost:13378";
                key = "{{HOMEPAGE_VAR_ABS_TOKEN}}";
              };
            };
          }
          {
            Plex = {
              icon = "plex.svg";
              href = "https://plex.baddog.ch";
              description = "Plex media server";
              widget = {
                type = "tautulli";
                url = "http://localhost:8181";
                key = "{{HOMEPAGE_VAR_TAUTULLI_KEY}}";
              };
            };
          }
          {
            qBittorrent = {
              icon = "qbittorrent.svg";
              href = "https://qbittorrent.lab.baddog.ch";
              description = "Torrents";
              widget = {
                type = "qbittorrent";
                url = "http://localhost:8081";
              };
            };
          }
          {
            SABnzbd = {
              icon = "sabnzbd.svg";
              href = "https://sabnzbd.lab.baddog.ch";
              description = "Usenet";
              widget = {
                type = "sabnzbd";
                url = "http://localhost:8080";
                key = "{{HOMEPAGE_VAR_SABNZBD_KEY}}";
              };
            };
          }
        ];
      }

      {
        Arr = [
          {
            Prowlarr = {
              icon = "prowlarr.svg";
              href = "https://prowlarr.lab.baddog.ch";
              description = "Indexers";
              widget = {
                type = "prowlarr";
                url = "http://localhost:9696";
                key = "{{HOMEPAGE_VAR_PROWLARR_KEY}}";
              };
            };
          }
          {
            Radarr = {
              icon = "radarr.svg";
              href = "https://radarr.lab.baddog.ch";
              description = "Movies";
              widget = {
                type = "radarr";
                url = "http://localhost:7878";
                key = "{{HOMEPAGE_VAR_RADARR_KEY}}";
              };
            };
          }
          {
            Sonarr = {
              icon = "sonarr.svg";
              href = "https://sonarr.lab.baddog.ch";
              description = "TV";
              widget = {
                type = "sonarr";
                url = "http://localhost:8989";
                key = "{{HOMEPAGE_VAR_SONARR_KEY}}";
              };
            };
          }
          {
            Lidarr = {
              icon = "lidarr.svg";
              href = "https://lidarr.lab.baddog.ch";
              description = "Music";
              widget = {
                type = "lidarr";
                url = "http://localhost:8686";
                key = "{{HOMEPAGE_VAR_LIDARR_KEY}}";
              };
            };
          }
        ];
      }

      {
        DNS = [
          {
            "NextDNS (Personal)" = {
              icon = "nextdns.svg";
              href = "https://my.nextdns.io/c216d3";
              description = "Personal DNS";
              widget = {
                type = "nextdns";
                profile = "c216d3";
                key = "{{HOMEPAGE_VAR_NEXTDNS}}";
              };
            };
          }
        ];
      }

      {
        Infra = [
          {
            Uptime = {
              icon = "uptime-kuma.svg";
              href = "https://uptime.lab.baddog.ch";
              description = "Uptime Kuma";
            };
          }
          {
            Tautulli = {
              icon = "tautulli.svg";
              href = "https://tautulli.lab.baddog.ch";
              description = "Plex stats";
            };
          }
          {
            Actual = {
              icon = "actual.svg";
              href = "https://actual.lab.baddog.ch";
              description = "Budget";
            };
          }
          {
            NAS = {
              icon = "synology.svg";
              href = "https://nas.lab.baddog.ch";
              description = "Synology";
            };
          }
        ];
      }
    ];
  };

  # ── NFS ───────────────────────────────────────────────────────────────────
  boot.supportedFilesystems = [ "nfs" ];
  services.rpcbind.enable = true;

  fileSystems."/mnt/nas/media" = {
    device = "192.168.1.117:/volume2/Data";
    fsType = "nfs";
    options = [
      "nfsvers=3"
      "soft"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "_netdev"
    ];
  };

  fileSystems."/mnt/nas/immich" = {
    device = "192.168.1.117:/volume2/Immich";
    fsType = "nfs";
    options = [
      "nfsvers=3"
      "hard"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "_netdev"
    ];
  };

  fileSystems."/mnt/nas/paperless" = {
    device = "192.168.1.117:/volume2/Paperless";
    fsType = "nfs";
    options = [
      "nfsvers=3"
      "hard"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "_netdev"
    ];
  };

}
