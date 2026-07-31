# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a homelab infrastructure repository managing services across multiple nodes connected via Tailscale:

| Node | Tailscale Name | Purpose |
|------|----------------|---------|
| **lab** | `lab.bonobo-torino.ts.net` | NixOS — all services (media, productivity, photos, documents) |
| **lighthouse** | `lighthouse.bonobo-torino.ts.net` | Public VPS — Caddy reverse proxy + Authelia for public-facing services |
| **homeassistant** | `homeassistant.bonobo-torino.ts.net` | Home Assistant OS (smart home) |

## Repository Structure

```
/
├── nixos/                     # NixOS configuration for "lab" node
│   ├── flake.nix              # Flake entrypoint (nixos-25.11 + sops-nix)
│   ├── configuration.nix      # All services, caddy, NFS, etc.
│   ├── hardware-configuration.nix
│   ├── secrets/               # SOPS-encrypted secrets
│   └── .sops.yaml             # SOPS config
│
├── ubuntu/                    # Legacy Docker stack (decommissioned)
│   ├── compose.yml
│   ├── media-compose.yml
│   ├── caddy/
│   ├── immich/
│   ├── paperless-ngx/
│   └── homepage/
│
├── homeassistant/             # Home Assistant config
│   ├── configuration.yaml
│   ├── automations.yaml
│   ├── scenes.yaml
│   ├── blueprints/
│   └── www/                   # Frontend cards (HACS)
│
└── CLAUDE.md
```

## Lab Node (NixOS)

### Common Commands

```bash
# Apply configuration changes
sudo nixos-rebuild switch --flake ~/homelab/nixos#lab

# Check service status
systemctl status <service-name>

# View service logs
journalctl -u <service-name> -f

# Manage Paperless
sudo paperless-manage <command>
```

### Architecture

**Services (all native NixOS modules, no Docker):**
- **Media:** Plex, Tautulli, Audiobookshelf
- **Arr stack:** Prowlarr, Radarr, Sonarr, Lidarr
- **Downloaders:** qBittorrent, SABnzbd
- **Photos:** Immich (PostgreSQL + Redis + ML, auto-managed)
- **Documents:** Paperless-ngx (SQLite, OCR: eng+deu+rus)
- **Apps:** Actual Budget, Uptime Kuma, Homepage Dashboard
- **Infra:** Caddy, Tailscale, SOPS secrets

**Reverse Proxy (two-tier):**
- **Lab Caddy** (`*.lab.baddog.ch`) — tailnet-only admin services, no auth layer (Tailscale is the auth)
- **Lighthouse Caddy** (`*.baddog.ch`) — public services (photos, plex, audiobookshelf) with Authelia OAuth

**Storage:**
NFS mounts from Synology NAS (`192.168.1.117` / `dionysos.bonobo-torino.ts.net`):
- `/mnt/nas/media` → `/volume2/Data` (movies, TV, music, torrents, usenet)
- `/mnt/nas/immich` → `/volume2/Immich` (photo library)
- `/mnt/nas/paperless` → `/volume2/Paperless` (documents)

**Secrets:**
Managed via SOPS + age. Key at `/home/baddog/.config/sops/age/keys.txt`.
- `tailscale_key` — Tailscale auth key
- `cf_api_token` — Cloudflare API token (Caddy DNS challenge)
- `homepage_env` — Homepage dashboard API keys

### Key Integrations

- **Media Pipeline:** Prowlarr → Radarr/Sonarr/Lidarr → qBittorrent/SABnzbd → Plex
- **Monitoring:** Tautulli for Plex stats, Uptime Kuma for service health

## Lighthouse Node

Public-facing VPS running Caddy + Authelia (Docker). Proxies public domains to lab's Tailscale IP (`100.101.71.81`):
- `photos.baddog.ch` → lab:2283 (Immich)
- `plex.baddog.ch` → lab:32400
- `audiobookshelf.baddog.ch` → lab:13378
- `auth.baddog.ch` → Authelia

Caddy config: `ssh root@lighthouse` → `/root/caddy/Caddyfile`

## Home Assistant Node

### Syncing Config

```bash
# Pull config from HA to repo
rsync -av --progress -e "ssh -p 22222" \
  --exclude='.storage' --exclude='*.db*' --exclude='*.log*' \
  --exclude='deps/' --exclude='tts/' --exclude='.cloud/' \
  --exclude='custom_components/' --exclude='.HA_VERSION' \
  root@homeassistant:/homeassistant/ ./homeassistant/

# Push config to HA
rsync -av --progress -e "ssh -p 22222" \
  --exclude='secrets.yaml' --exclude='go2rtc.yaml' \
  ./homeassistant/ root@homeassistant:/homeassistant/
```

### Key Components

**Integrations:**
- Philips Hue (lights, rooms)
- Zigbee (ZHA) - IKEA remotes (STYRBAR, Somrig), sensors
- Marantz CINEMA 70s AVR
- XGIMI projector
- Tapo cameras (via go2rtc)
- Robot vacuum (Saros 10R)

**Automations:**
- Bedtime routines (lights dim, media off, sleep music)
- Dimmer switch controls (Hue, IKEA)
- Media player auto-control (projector turns off lights)
- Plant humidity alerts
- Wake-up light sequences

**Custom Components (via HACS):**
- dlight
- webrtc

### Secrets Management

- `secrets.yaml` - Contains actual secrets (gitignored)
- `secrets.yaml.example` - Template with placeholders
- `go2rtc.yaml` - Camera streams with credentials (gitignored)
- `go2rtc.yaml.example` - Template without credentials

## Deployment Workflow

1. Edit `nixos/configuration.nix`
2. `sudo nixos-rebuild switch --flake ~/homelab/nixos#lab`
3. For HA: Use rsync to push config, then reload via HA UI or `ha core restart`
