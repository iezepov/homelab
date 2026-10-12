{ config, pkgs, lib, ... }:

# ── Unattended weekly maintenance ─────────────────────────────────────────────
# Two separate jobs on purpose, so that a bad upstream commit can never turn
# into a reboot loop:
#
#   1. lab-update  (Sun 03:30) - refresh every flake input, rebuild, switch.
#      Runs as root (only root can move /nix/var/nix/profiles/system) but drops
#      to baddog for the git/nix steps so the checkout stays baddog-owned.
#      If anything fails, the previous flake.lock is restored and the running
#      generation is untouched - a broken commit costs one week, not the box.
#      On success the new lock file is committed and pushed, so the git history
#      stays the rollback trail.
#
#   2. lab-reboot  (Sun 04:30) - reboots ONLY when /run/current-system is not
#      what was booted, i.e. when a kernel/initrd/systemd change is genuinely
#      pending. In practice that is most weeks, because the pinned nixpkgs
#      branch keeps moving - but it will never reboot just to reboot.
#
# This exists because the box once sat at 73 days of uptime booting kernel
# 6.12.81 while the switched generation already shipped 6.12.93: a rebuild only
# takes effect on disk until you actually boot it.
#
# The disk guard and the generation pruning are here because / is a 56G fs and
# a release bump plus a major Immich jump transiently needs ~20G: the 26.05
# upgrade drove it from 23G free to 2.8G free (95%) before it was caught, and it
# was the ~18G of old system generations that had to give.

let
  repo = "/home/baddog/homelab";
  flake = "${repo}/nixos#lab";
  # git/nix for baddog, with a login-ish environment so no root ownership or
  # missing-HOME surprises leak into the checkout
  # util-linux supplies runuser; the unit's PATH is only what is listed below,
  # so anything the script calls must be there or be referenced absolutely.
  asBaddog = "runuser -u baddog -- env HOME=/home/baddog";
  # nixos-rebuild is not in pkgs - it lives in the running system profile
  nixosRebuild = "/run/current-system/sw/bin/nixos-rebuild";
  # how many system generations (plus the booted one) stay as rollback targets
  keepGenerations = 5;
  minFreeMiB = 12582912; # 12 GiB
in
{
  systemd.services.lab-update = {
    description = "Weekly flake input update + nixos-rebuild switch";
    startAt = "Sun 03:30";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = with pkgs; [
      git
      nix
      coreutils
      gnugrep
      gawk
      util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "3h";
      Nice = 10;
      # libgit2 is what nix uses to read this git-repo flake, and unlike the git
      # CLI it does not consult /etc/gitconfig for safe.directory - it reads
      # $HOME/.gitconfig. A systemd unit has no HOME, which made the rebuild die
      # with "repository path '/home/baddog/homelab' is not owned by current
      # user". See the declarative gitconfig below.
      Environment = [ "HOME=/root" ];
    };
    script = ''
      set -euo pipefail
      cd ${repo}/nixos

      before=$(readlink -f /nix/var/nix/profiles/system)
      echo "running generation: $before"

      cleanup() {
        rc=$?
        if [ "$rc" -ne 0 ]; then
          echo "lab-update FAILED (rc=$rc) - restoring the previous flake.lock;"
          echo "the running generation is unchanged, nothing was switched."
          ${asBaddog} git -C ${repo} checkout -- nixos/flake.lock || true
        fi
        exit "$rc"
      }
      trap cleanup EXIT

      # Refuse to start an upgrade that cannot fit. A release bump needs room for
      # a whole new closure while the old one is still live, and filling / has
      # taken Postgres and Immich off this box before.
      free_mib=$(df -Pk / | awk 'NR==2 {print $4}')
      if [ "$free_mib" -lt ${toString minFreeMiB} ]; then
        echo "only $((free_mib / 1024)) MiB free on / - refusing to update."
        echo "prune old generations first:"
        echo "  nix-env -p /nix/var/nix/profiles/system --delete-generations +${toString keepGenerations} && nix-collect-garbage"
        exit 1
      fi
      echo "free space on /: $((free_mib / 1024)) MiB (ok)"

      # start from a clean lock so last week's failed attempt can't compound
      ${asBaddog} git -C ${repo} checkout -- nixos/flake.lock || true

      echo "== nix flake update =="
      ${asBaddog} nix flake update

      echo "== nixos-rebuild switch =="
      ${nixosRebuild} switch --flake ${flake}

      after=$(readlink -f /nix/var/nix/profiles/system)
      echo "generation now: $after"

      # Bound generation growth in both cases: nix.gc only prunes paths older
      # than 30d, and this filesystem is too small to keep a month of closures.
      # Doing it before the early exit means the box is still tidied in weeks
      # where upstream did not move.
      prune_and_gc() {
        nix-env -p /nix/var/nix/profiles/system --delete-generations "+${toString keepGenerations}" || true
        nix-collect-garbage || true
        df -h / | tail -1
      }

      if [ "$before" = "$after" ]; then
        echo "no input change - nothing to commit, and no reboot will be needed"
        prune_and_gc
        exit 0
      fi

      ${asBaddog} git -C ${repo} add nixos/flake.lock
      ${asBaddog} git -C ${repo} commit \
        -m "chore(flake): weekly input update ($(date -I))" || true
      ${asBaddog} git -C ${repo} push origin HEAD \
        || echo "warning: push failed - lock file committed locally only"
      echo "committed + pushed the new flake.lock"

      prune_and_gc
    '';
  };

  systemd.services.lab-reboot-if-pending = {
    description = "Reboot only if a switched generation has not been booted yet";
    startAt = "Sun 04:30";
    path = with pkgs; [
      coreutils
      systemd
    ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "5min";
    };
    script = ''
      set -euo pipefail
      current=$(readlink -f /run/current-system)
      booted=$(readlink -f /run/booted-system)

      if [ "$current" = "$booted" ]; then
        echo "already running the current generation ($current) - no reboot needed"
        exit 0
      fi

      echo "pending: $current"
      echo "booted : $booted"
      echo "kernel/system change is not live yet - rebooting"
      systemctl reboot
    '';
  };

  # catch up if the box happened to be off at 03:30/04:30
  systemd.timers.lab-update.timerConfig.Persistent = true;
  systemd.timers.lab-reboot-if-pending.timerConfig.Persistent = true;

  # A rebuild needs far more than the 1024 fds an ssh/PAM session is handed:
  # the first 26.05 build died with `opening directory "/nix/store": Too many
  # open files`. sshd and nix-daemon already run with large limits (524288 /
  # 1048576) - it is the *session* limit that is low, so raise it for humans and
  # hand our own units an explicit limit as well.
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "65536";
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "524288";
    }
  ];
  systemd.services.lab-update.serviceConfig.LimitNOFILE = 65536;

  # hermes-agent.nix declares programs.git.config."safe".directory, but nixpkgs
  # only emits /etc/gitconfig when programs.git.enable is set - so until now
  # nothing but a hand-written /root/.gitconfig carried that exception. Enable
  # it, and point root's config at it so libgit2 finds it too.
  programs.git.enable = true;
  systemd.tmpfiles.rules = [ "L+ /root/.gitconfig - - - - /etc/gitconfig" ];
  systemd.services.lab-reboot-if-pending.serviceConfig.LimitNOFILE = 65536;
}
