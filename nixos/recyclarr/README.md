# Recyclarr (TRaSH-Guides) for lab — how this is run today

`recyclarr.yml` here is the **source of truth** for the quality profiles and custom formats of
Radarr and Sonarr on `lab`. It is not yet wired into the flake as a service; until it is, it is
applied by hand, as root, on `lab`:

```bash
# 1. the config
install -d -o baddog -g users /var/lib/recyclarr-work
cp /home/baddog/homelab/nixos/recyclarr/recyclarr.yml /var/lib/recyclarr-work/
chown baddog:users /var/lib/recyclarr-work/recyclarr.yml

# 2. run it (keys come from each app's config.xml, never from this file)
cat > /tmp/rc_sync.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
RADARR_API_KEY=$(grep -oP '(?<=<ApiKey>)[^<]+' /var/lib/radarr/.config/Radarr/config.xml)
SONARR_API_KEY=$(grep -oP '(?<=<ApiKey>)[^<]+' /var/lib/sonarr/.config/NzbDrone/config.xml)
export RADARR_API_KEY SONARR_API_KEY COLUMNS=200 TERM=xterm-256color
cd /var/lib/recyclarr-work
exec script -qec "nix-shell -p recyclarr --run \"recyclarr sync -c /var/lib/recyclarr-work/recyclarr.yml\"" /dev/null
EOF
chmod 700 /tmp/rc_sync.sh && bash /tmp/rc_sync.sh sync

# 3. preview instead of applying
bash /tmp/rc_sync.sh sync --preview
```

## Two things that will bite you

- **`script -qec` is not optional.** Recyclarr 8.6.0 renders progress with Spectre.Console and
  crashes with `Offset and length were out of bounds for the array…` when stdout is not a TTY
  (i.e. every `ssh lab '...'` invocation). Under a pty it works. Preview mode exits before the
  progress renderer starts, which is why `--preview` works without the wrapper but a real sync
  does not.
- **Quality names in `qualities:` must be real groups, not bare labels.** `WEB 1080p` is only
  valid when declared with its members (`qualities: [WEBDL-1080p, WEBRip-1080p]`); otherwise
  Recyclarr reports it as an invalid quality name.

## The design (agreed with Ilya, 2026-10-20)

| profile | who is on it | quality order (best first) | upgrade until |
| --- | --- | --- | --- |
| `4K first` | Seerr requests, TMDB collections | Bluray-2160p → WEB 2160p → Bluray-1080p → WEB 1080p → HDTV-1080p | Bluray-2160p, custom-format score 10000 |
| `1080p keep` | the existing library (169 movies, 40 series) | Bluray-1080p → WEB 1080p → HDTV-1080p | WEB 1080p, **custom-format score 0** |
| `Fallback (720p ok)` | per-item escape hatch for rare media | as above + 720p qualities | WEB 1080p |

- **Remux is excluded everywhere** — Ilya does not want 20-60 GB files. Existing remuxes stay.
- `until_score: 0` on `1080p keep` is deliberate: TRaSH's default keeps upgrading on
  custom-format score forever, which would re-download the whole 1080p library. With 0, only
  files *below* WEB 1080p (CAM/TS/HDTV/DVD/480p) get replaced.
- Custom-format groups synced: Golden Rule (HD/UHD), DV Boost, HDR, Audio, Streaming Services
  General, Unwanted Formats, and `MULTi` (Russian dual-audio releases get a small bonus — Ilya
  wants original language first, dub as a nice-to-have).
- Quality *sizes* come from TRaSH `type: movie` / `type: series`. TRaSH sets max/preferred to
  "unlimited", so in practice only the minimum sizes are enforced; the real size guard here is
  the exclusion of Remux.
