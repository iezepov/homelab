{ config, ... }:

{
  sops.secrets.homepage_env = {
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
            "Caddy (lab)" = {
              icon = "caddy.svg";
              href = "https://lab.baddog.ch";
              description = "Private reverse proxy";
              widget = {
                type = "caddy";
                url = "http://localhost:2019";
              };
            };
          }
          {
            "Caddy (Public)" = {
              icon = "caddy.svg";
              href = "https://baddog.ch";
              description = "Public reverse proxy";
              widget = {
                type = "caddy";
                url = "http://lighthouse.bonobo-torino.ts.net:2019";
              };
            };
          }
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
}
