# Homelab Repository Guide

This repository contains infrastructure for three Tailscale-connected systems:

- `lab` (`lab.bonobo-torino.ts.net`): the primary NixOS host. Its complete declarative configuration is under `nixos/`; service definitions are split across `nixos/modules/`.
- `homeassistant` (`homeassistant.bonobo-torino.ts.net`): Home Assistant OS configuration tracked under `homeassistant/`.
- `lighthouse` (`lighthouse.bonobo-torino.ts.net`): an externally managed public VPS. Its Caddy/Authelia configuration is not stored in this repository.

The NixOS `lab` and Home Assistant OS `homeassistant` systems run as Proxmox VMs on the same physical host. The coding agent runs on the `lab` NixOS VM, so local commands and service inspection target that system unless stated otherwise.

`ubuntu/` is the legacy Docker deployment and is retained for reference; it is not the current lab deployment.

## Important operational details

- The active NixOS flake target is `nixos#lab`, using nixpkgs `nixos-25.11`, sops-nix, VPN-Confinement, and the Pi NixOS module.
- Apply lab changes with:
  `sudo nixos-rebuild switch --flake ~/homelab/nixos#lab`
- Secrets are managed with SOPS and age. The local age key is expected at `/home/baddog/.config/sops/age/keys.txt`; do not replace encrypted secrets with plaintext. Current secret names include `tailscale_key`, `cf_api_token`, `homepage_env`, and `protonvpn_wg_conf`.
- Lab storage is provided by NFS from the Synology NAS at `192.168.1.117` and mounted under `/mnt/nas/`. The mount definitions and service-specific paths are authoritative in `nixos/configuration.nix` and the modules.
- The lab uses Intel GPU acceleration for Plex and Immich. Keep their `render`/`video` device access aligned with the host graphics configuration when changing media services.
- `nixos/modules/vpn.nix` defines a ProtonVPN WireGuard namespace and NAT-PMP port renewal. Downloader VPN confinement in `media.nix` is currently commented out; do not assume qBittorrent or SABnzbd are VPN-routed without checking the live configuration.
- Lab Caddy is configured in `nixos/modules/caddy.nix`; Lighthouse Caddy is separate external state. Public services are proxied from Lighthouse to the lab over Tailscale, so changes to public routing may require work on both hosts.

## Home Assistant synchronization

The checked-in Home Assistant configuration intentionally excludes runtime state and secrets. When synchronizing with the HA host, preserve these exclusions:

- `.storage`, databases, logs, `deps/`, `tts/`, `.cloud/`, `custom_components/`, and `.HA_VERSION`
- `secrets.yaml` and `go2rtc.yaml` when pushing from this repository

The repository contains examples for `secrets.yaml` and `go2rtc.yaml`; the live files are not tracked. HACS components and other excluded runtime configuration may exist only on the Home Assistant host.

The canonical HA deployment path is `/homeassistant/`; after pushing configuration, reload or restart Home Assistant through the HA interface/CLI as appropriate.

## Remote agent access (Hermes)

Hermes does not run on this host. It runs on a separate Proxmox VM (`hermes`, tailnet
`100.117.67.0`) and manages lab remotely, so local-only assumptions in this file still
apply to whichever agent is running *here*.

- **SSH:** `ssh -p 2222 hermes@lab.baddog.ch`. Port 22 is answered by Tailscale SSH with an
  interactive per-session check, so automation uses a dedicated sshd instance on **2222**
  (`sshd-hermes.service`, config `/etc/ssh/sshd-hermes.conf`, `AllowUsers hermes`).
- **Privileges:** the `hermes` account (uid 1001) has `NOPASSWD: ALL` sudo, scoped to that
  account only — `baddog` keeps the normal password-required behaviour. Defined in
  `nixos/modules/hermes-agent.nix`.
- **Shared identity:** `hermes` uses the same key as the Home Assistant SSH add-on
  (`hermes-agent-ha`). Rotating that key means updating every host that trusts it.
- **Repo hygiene:** `/home/baddog` is `0700`, so the agent does git work as baddog
  (`sudo -u baddog -H git -C /home/baddog/homelab ...`) to keep object ownership correct.
  Flakes only evaluate git-tracked files: `git add` new files before rebuilding.
- **Apply:** `sudo nixos-rebuild switch --flake /home/baddog/homelab/nixos#lab`; roll back
  with `--rollback` or by reverting the commit. The sops/age key is readable as root, so the
  agent can build and switch unattended.
