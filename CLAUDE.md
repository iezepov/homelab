# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a homelab Docker Compose stack running on an Ubuntu VM (Proxmox) managing media, productivity, and home services. All services are orchestrated through a hierarchical compose structure with Caddy as the reverse proxy.

## Common Commands

```bash
# Start all services
docker compose up -d

# Restart a specific service
docker compose restart <service-name>

# View logs for a service
docker logs <container-name> --tail 100 -f

# Rebuild caddy after Caddyfile changes
docker compose build caddy && docker compose up -d caddy

# Pull latest images and recreate
docker compose pull && docker compose up -d
```

## Architecture

### Compose Structure
- `compose.yml` - Main entrypoint, includes other compose files via `include:`
  - `media-compose.yml` - Media stack (Jellyfin, Plex, *arr apps, downloaders)
  - `immich/docker-compose.yml` - Photo management
  - `paperless-ngx/docker-compose.yml` - Document management

### Networks
- `app` - Main bridge network for inter-service communication
- `paperless_internal_network` - Isolated internal network for Paperless DB/broker

### Storage
NFS volumes from Synology NAS (IP configured via `NAS_IP` env var, default `192.168.1.117`):
- `nas-media` - Media library (movies, TV, music, torrents, usenet)
- `nas-immich` - Immich photo uploads
- `nas-paperless` - Paperless documents

NFS mounts are defined as Docker volumes in compose files (not system fstab).

### Reverse Proxy
Caddy with custom build (`caddy/Dockerfile`) including:
- `caddy-dns/cloudflare` - DNS challenge for wildcard certs
- Forward auth via Authelia at `lighthouse.bonobo-torino.ts.net:31306`

All services exposed as `<service>.lab.baddog.ch` subdomains.

### Environment Variables
Root `.env` file provides:
- `TZ`, `PUID`, `PGID` - Standard LinuxServer.io vars
- `NAS_IP` - Synology NAS IP for NFS volumes (default: 192.168.1.117)
- `TS_AUTHKEY` - Tailscale auth key

Service-specific `.env` files exist in: `immich/`, `paperless-ngx/`, `tandoor/`

## Key Integrations

**Media Pipeline:** Prowlarr → Radarr/Sonarr/Lidarr → qBittorrent/SABnzbd → Jellyfin/Plex

**VPN Routing:** Tailscale gateway container configured with exit node for download clients

**Monitoring:** Watchtower for auto-updates, Tautulli for Plex stats, Speedtest-tracker for bandwidth
