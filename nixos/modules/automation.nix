{ config, pkgs, lib, ... }:

# ── Unattended weekly maintenance ─────────────────────────────────────────────
# Two separate jobs on purpose, so that a bad upstream commit can never turn
# into a reboot loop:
#
#   1. lab-update  (Sun 03:30) - refresh every flake input, build, switch.
#      Runs as root (only root can move /nix/var/nix/profiles/system) but drops
#      to baddog for the git/nix steps so the checkout stays baddog-owned.
#      It builds the new system BEFORE switching, so a broken upstream commit
#      costs nothing at all; only a failed build restores the previous
#      flake.lock, and only when the running generation really did not move.
#      Success is judged by the generation/profile, never by this script's exit
#      code (the switch restarts units, so the script can die with work done).
#      On success the new lock file is committed and pushed, so the git history
#      stays the rollback trail. The unit is marked restartIfChanged = false so
#      the switch cannot stop the job that is performing it.
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
      systemd
      # `git push` shells out to ssh: without this every weekly push died with
      # "error: cannot run ssh: No such file or directory" and the lock commits
      # never left the box.
      openssh
    ];
    # ── Do not let the switch kill the job that performs it ──────────────────
    # switch-to-configuration restarts every unit whose definition changed, and a
    # flake bump moves the store paths inside this unit (its script and its PATH),
    # so on 2026-10-25 it TERM'd lab-update mid-switch. That left a stale
    # nixos-rebuild-switch-to-configuration.service loaded, so the automatic retry
    # died with "Unit ... was already loaded" (nixpkgs#319440) and the failure
    # handler reverted flake.lock while the new generation kept running - which
    # made the next rebuild downgrade Immich 3.3.5 -> 3.3.1 against a database
    # 3.3.5 had already migrated, and photos.baddog.ch served 502s for 23h.
    # Upstream's nixos-upgrade.service protects itself with the same markers.
    restartIfChanged = false;
    stopIfChanged = false;
    unitConfig.X-StopOnRemoval = false;
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

      profile=/nix/var/nix/profiles/system
      lockfile=${repo}/nixos/flake.lock
      lock_backup=$(mktemp /tmp/lab-update-flake.lock.XXXXXX)
      before=$(readlink -f "$profile")
      cp -a "$lockfile" "$lock_backup"
      echo "running generation: $before"

      commit_lock() {
        ${asBaddog} git -C ${repo} add nixos/flake.lock || true
        ${asBaddog} git -C ${repo} commit \
          -m "chore(flake): weekly input update ($(date -I))" \
          || echo "nothing new to commit"
        ${asBaddog} git -C ${repo} push origin HEAD \
          || echo "warning: push failed - lock file committed locally only"
      }

      # Bound generation growth in both cases: nix.gc only prunes paths older
      # than 30d, and this filesystem is too small to keep a month of closures.
      prune_and_gc() {
        nix-env -p "$profile" --delete-generations "+${toString keepGenerations}" || true
        nix-collect-garbage || true
        df -h / | tail -1
      }

      # A previous killed run can leave this transient unit loaded, and then every
      # later switch fails with "Unit ... was already loaded" (nixpkgs#319440).
      clear_transient() {
        systemctl stop nixos-rebuild-switch-to-configuration.service 2>/dev/null || true
        systemctl reset-failed nixos-rebuild-switch-to-configuration.service 2>/dev/null || true
      }

      cleanup() {
        rc=''${1:-$?}
        trap - EXIT TERM INT
        after=$(readlink -f "$profile")

        if [ "$rc" -ne 0 ]; then
          if [ "$after" != "$before" ]; then
            # The switch DID land; only this process died while performing it.
            # Reverting the lock here pins the box to an older revision and
            # downgrades every app whose database has already migrated, so keep
            # the forward state and record it.
            echo "lab-update: rc=$rc, but the generation DID change:"
            echo "  before: $before"
            echo "  after : $after"
            echo "  keeping the updated flake.lock - a rollback would downgrade migrated databases"
            commit_lock
          else
            echo "lab-update FAILED (rc=$rc) with the generation unchanged."
            echo "restoring the previous flake.lock - nothing was switched."
            cp -a "$lock_backup" "$lockfile" || true
          fi
        fi

        rm -f "$lock_backup"
        exit "$rc"
      }
      trap cleanup EXIT
      trap 'cleanup 143' TERM
      trap 'cleanup 130' INT

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
      cp -a "$lockfile" "$lock_backup"

      echo "== nix flake update =="
      ${asBaddog} nix flake update

      # Build BEFORE switching: a bad upstream commit then costs nothing, and
      # there is never a half-applied generation to reason about afterwards.
      echo "== nix build (builds the new system, switches nothing) =="
      ${asBaddog} nix build --no-link --print-out-paths \
        "${repo}/nixos#nixosConfigurations.lab.config.system.build.toplevel"

      echo "== nixos-rebuild switch =="
      clear_transient
      if ! ${nixosRebuild} switch --flake ${flake}; then
        after=$(readlink -f "$profile")
        if [ "$after" = "$before" ]; then
          echo "switch failed and nothing was switched - clearing the transient unit and retrying once"
          clear_transient
          ${nixosRebuild} switch --flake ${flake}
        else
          echo "switch returned non-zero but the generation advanced - continuing"
        fi
      fi

      after=$(readlink -f "$profile")
      echo "generation now: $after"
      echo "booted now    : $(readlink -f /run/booted-system)"

      # sha256sum (coreutils) and not cmp (diffutils): every command in this
      # script must come from the unit's own PATH list, or it fails at runtime
      # with "command not found" only when that branch is finally reached.
      if [ "$(sha256sum < "$lockfile")" = "$(sha256sum < "$lock_backup")" ]; then
        echo "no input change - nothing to commit"
      else
        commit_lock
      fi

      if [ "$before" = "$after" ]; then
        echo "no system change either - no reboot will be needed"
      fi

      prune_and_gc
    '';
  };

  # The VM disk was enlarged 64G -> 128G on 2026-10-12, but a running kernel cannot
  # re-read the partition table of a disk whose root partition is mounted, and the
  # on-disk table (sda1 = 2048..end, swap partition removed) is already correct. So
  # claim the space at boot instead: resize2fs is an online grow and a no-op once the
  # filesystem already fills its partition, which makes "enlarge the VM disk, reboot"
  # the whole procedure from now on.
  systemd.services.grow-root-filesystem = {
    description = "Grow the root filesystem to fill its partition (no-op when already done)";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    unitConfig.ConditionPathIsMountPoint = "/";
    # util-linux for findmnt; a unit sees only what its path lists (this is the same
    # trap that made `runuser` and later `findmnt` "command not found").
    path = with pkgs; [
      e2fsprogs
      util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
    };
    script = ''
      dev=$(findmnt -no SOURCE /)
      echo "root device: $dev"
      resize2fs "$dev" || echo "resize2fs reported a problem - see above"
      df -h / | tail -1
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
