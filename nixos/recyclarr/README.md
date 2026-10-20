# Recyclarr (TRaSH-Guides) for lab

`recyclarr.yml` here is the **source of truth** for the Radarr and Sonarr quality profiles and
custom formats. It is installed read-only to `/etc/recyclarr/recyclarr.yml` and applied by
`recyclarr.service` (oneshot) on `recyclarr.timer` — **weekly**, `Persistent=true`, plus a random
delay of up to an hour.

```bash
systemctl start recyclarr            # apply now
systemctl list-timers recyclarr      # when is the next run
journalctl -u recyclarr -n 50        # what the last run did
```

Declared in `nixos/modules/recyclarr.nix`. The two API keys are not in this file: the YAML uses
`!env_var`, and the values come from the sops secret **`recyclarr_env`** (an env-format secret with
`RADARR_API_KEY` / `SONARR_API_KEY`), injected via `EnvironmentFile` by systemd as root before the
service drops to the `recyclarr` user.

## Three traps, all of them cost a round trip

1. **Recyclarr needs a TTY.** Its Spectre.Console progress renderer aborts with
   `Offset and length were out of bounds for the array…` whenever stdout is not a pty — i.e. under
   systemd *and* on every `ssh lab '…'` call. `--preview` is unaffected (it exits before the renderer
   starts), which makes it look like an apply-only bug. Hence the `script -qec` wrapper in the module.
2. **That wrapper needs a shell.** `script` execs the account's login shell, so the `recyclarr`
   system user gets `shell = pkgs.bash`; with the default nologin it dies with
   *"This account is currently not available."*
3. **`qualities:` needs real groups, not labels.** `WEB 1080p` is only valid declared with its
   members (`qualities: [WEBDL-1080p, WEBRip-1080p]`); a bare label is rejected as an invalid
   quality name.

## The design (agreed with Ilya, 2026-10-20)

| profile | who is on it | quality order (best first) | upgrade until |
| --- | --- | --- | --- |
| `4K first` | Seerr requests, TMDB collections | Bluray-2160p → WEB 2160p → WEB 1080p → Bluray-1080p → HDTV-1080p | Bluray-2160p, custom-format score 10000 |
| `1080p keep` | the existing library (169 movies, 40 series) | WEB 1080p → Bluray-1080p → HDTV-1080p | Bluray-1080p, **custom-format score 0** |
| `Fallback (720p ok)` | per-item escape hatch for rare media | as above + 720p qualities | WEB 1080p |

- **WEB outranks Bluray at 1080p** (Ilya's call: same resolution, far smaller file — a Bluray-1080p
  encode can be 23 GB where the WEB-DL is 6). A consequence worth remembering: the upgrade cutoff
  must then be `Bluray-1080p`, the *lowest* quality still considered good. With the cutoff at
  `WEB 1080p` every existing Bluray-1080p file would read as below-cutoff and be re-downloaded as a
  WEB copy — a whole-library churn for no quality gain.
- **Remux is excluded everywhere** — Ilya does not want 20-60 GB files. Existing remuxes stay.
- `until_score: 0` on `1080p keep` is deliberate: TRaSH's default keeps upgrading on custom-format
  score forever, which would re-download the whole 1080p library. With 0, only files *below*
  WEB 1080p (CAM/TS/HDTV/DVD/480p) get replaced.
- Custom-format groups synced: Golden Rule (HD/UHD), DV Boost, HDR, Audio, Streaming Services
  General, Unwanted Formats, and `MULTi` (Russian dual-audio releases get a small bonus — Ilya
  wants original language first, dub as a nice-to-have).
- Quality *sizes* come from TRaSH `type: movie` / `type: series`. TRaSH sets max/preferred to
  "unlimited", so only minimum sizes are enforced; the real size guard is excluding Remux.
- Profile ids are **7/8/9** in both apps. Seerr's Radarr/Sonarr settings point at **7**
  (`4K first`); everything already in the library is on **8**.

## Changing the profiles

Edit `recyclarr.yml`, commit, `nixos-rebuild switch --flake /home/baddog/homelab/nixos#lab`, then
`systemctl start recyclarr`. Recyclarr reconciles by profile name and TRaSH `trash_id`, so renaming a
profile in this file creates a new one rather than renaming the live one.
