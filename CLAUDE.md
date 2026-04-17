# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a multi-node homelab infrastructure repository managing two Proxmox VMs connected via Tailscale:

| Node | Tailscale Name | Purpose |
|------|----------------|---------|
| **ubuntu** | `ubuntu.bonobo-torino.ts.net` | Docker Compose stack (media, productivity, services) |
| **homeassistant** | `homeassistant.bonobo-torino.ts.net` | Home Assistant OS (smart home) |

## Repository Structure

```
/
├── ubuntu/                 # Docker stack on ubuntu node
│   ├── compose.yml         # Main entrypoint
│   ├── media-compose.yml   # Media services
│   ├── caddy/              # Reverse proxy
│   ├── immich/             # Photo management
│   ├── paperless-ngx/      # Document management
│   └── homepage/           # Dashboard
│
├── homeassistant/          # Home Assistant config
│   ├── configuration.yaml  # Main HA config
│   ├── automations.yaml    # Automations
│   ├── scenes.yaml         # Scenes
│   ├── blueprints/         # Automation blueprints
│   └── www/                # Frontend cards (HACS)
│
└── CLAUDE.md
```

## Connecting to Nodes

```bash
# Ubuntu node (local or via Tailscale)
ssh ubuntu
ssh ubuntu.bonobo-torino.ts.net

# Home Assistant (SSH add-on on port 22222)
ssh -p 22222 root@homeassistant
```

## Ubuntu Node - Docker Stack

### Common Commands

```bash
cd ~/homelab/ubuntu

# Start all services
docker compose up -d

# Restart a specific service
docker compose restart <service-name>

# View logs
docker logs <container-name> --tail 100 -f

# Rebuild caddy after Caddyfile changes
docker compose build caddy && docker compose up -d caddy

# Pull latest images and recreate
docker compose pull && docker compose up -d
```

### Architecture

**Compose Structure:**
- `compose.yml` - Main entrypoint, includes other compose files via `include:`
  - `media-compose.yml` - Media stack (Jellyfin, Plex, *arr apps, downloaders)
  - `immich/docker-compose.yml` - Photo management
  - `paperless-ngx/docker-compose.yml` - Document management

**Networks:**
- `app` - Main bridge network for inter-service communication
- `paperless_internal_network` - Isolated internal network for Paperless DB/broker

**Storage:**
NFS volumes from Synology NAS (IP configured via `NAS_IP` env var, default `192.168.1.117`):
- `nas-media` - Media library (movies, TV, music, torrents, usenet)
- `nas-immich` - Immich photo uploads
- `nas-paperless` - Paperless documents

**Reverse Proxy:**
Caddy with custom build including:
- `caddy-dns/cloudflare` - DNS challenge for wildcard certs
- Forward auth via Authelia at `lighthouse.bonobo-torino.ts.net:31306`
- All services exposed as `<service>.lab.baddog.ch` subdomains

**Environment Variables:**
- Root `.env` provides: `TZ`, `PUID`, `PGID`, `NAS_IP`, `TS_AUTHKEY`
- Service-specific `.env` files in: `immich/`, `paperless-ngx/`

### Key Integrations

- **Media Pipeline:** Prowlarr → Radarr/Sonarr/Lidarr → qBittorrent/SABnzbd → Jellyfin/Plex
- **VPN Routing:** Tailscale gateway container configured with exit node for download clients
- **Monitoring:** Watchtower for auto-updates, Tautulli for Plex stats, Speedtest-tracker for bandwidth

## Home Assistant Node

### Syncing Config

```bash
# Pull config from HA to repo (from ubuntu node)
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

1. Make changes in this repo
2. Commit and push
3. For ubuntu: `cd ~/docker/ubuntu && git pull && docker compose up -d`
4. For HA: Use rsync to push config, then reload via HA UI or `ha core restart`
