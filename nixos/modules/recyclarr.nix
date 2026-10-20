{ config, lib, pkgs, ... }:

# Recyclarr keeps the Radarr/Sonarr quality profiles and custom formats in sync with the
# TRaSH-Guides. The configuration itself lives in the repo at nixos/recyclarr/recyclarr.yml and is
# installed read-only to /etc; the two API keys come from the sops secret `recyclarr_env` as
# environment variables, which is what the YAML's `!env_var` references resolve against.
#
# Deliberately NOT using nixpkgs' services.recyclarr module: its ExecStart runs recyclarr without a
# TTY, and recyclarr 8.x then dies with "Offset and length were out of bounds for the array…" from
# the Spectre.Console progress renderer. The wrapper below hands it a pty via `script`.

let
  configFile = "/etc/recyclarr/recyclarr.yml";
  syncScript = pkgs.writeShellScript "recyclarr-sync" ''
    set -eu
    exec ${pkgs.util-linux}/bin/script -qec \
      "${lib.getExe pkgs.recyclarr} sync --config ${configFile}" /dev/null
  '';
in
{
  users.users.recyclarr = {
    isSystemUser = true;
    group = "recyclarr";
    home = "/var/lib/recyclarr";
    description = "Recyclarr (TRaSH-Guides profile sync)";
    # `script` (the pty wrapper) execs the account's login shell; a nologin shell fails with
    # "This account is currently not available."
    shell = pkgs.bash;
  };
  users.groups.recyclarr = { };

  # read by systemd itself (EnvironmentFile), before it drops to the recyclarr user
  sops.secrets.recyclarr_env = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  environment.etc."recyclarr/recyclarr.yml".source = ../recyclarr/recyclarr.yml;

  systemd.services.recyclarr = {
    description = "Recyclarr - sync TRaSH-Guides quality profiles to Radarr/Sonarr";
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "radarr.service"
      "sonarr.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "recyclarr";
      Group = "recyclarr";
      StateDirectory = "recyclarr";
      EnvironmentFile = config.sops.secrets.recyclarr_env.path;
      Environment = [
        "HOME=/var/lib/recyclarr"
        "COLUMNS=200"
        "TERM=xterm-256color"
      ];
      ExecStart = syncScript;

      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectHostname = true;
      ProtectClock = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
      NoNewPrivileges = true;
      RestrictSUIDSGID = true;
      RemoveIPC = true;
      LockPersonality = true;
      RestrictRealtime = true;
      CapabilityBoundingSet = "";
      ReadWritePaths = [ "/var/lib/recyclarr" ];
    };
  };

  systemd.timers.recyclarr = {
    description = "Weekly TRaSH-Guides profile sync (Recyclarr)";
    wantedBy = [ "timers.target" ];
    partOf = [ "recyclarr.service" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
