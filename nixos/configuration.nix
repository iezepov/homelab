{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ── Sops ──────────────────────────────────────────────────────────────────
  sops.defaultSopsFile = ./secrets/secrets.yaml;
  sops.age.keyFile = "/etc/age/keys.txt";
  sops.secrets.tailscale_key = {};

  # ── Boot ──────────────────────────────────────────────────────────────────
  boot.loader.grub.devices = [ "/dev/sda" ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/afbdac41-286c-4e79-b479-a571c9e3f29b";
    fsType = "ext4";
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/dd6280da-e49e-4a4e-b183-87e32c7aa314"; }
  ];

  # ── System ────────────────────────────────────────────────────────────────
  networking.hostName = "lab";
  networking.useDHCP = true;
  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.05";

  # ── User ──────────────────────────────────────────────────────────────────
  users.users.baddog = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEOdHCXMy6xXALJZWwHCQj5iUqK/YxLoR3nOq7KjijZE ilya@baddog.ch"
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  # ── SSH ───────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # ── Packages ──────────────────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [ git lazygit vim htop curl wget nfs-utils ];
  environment.variables.EDITOR = "vim";

  # ── Tailscale ─────────────────────────────────────────────────────────────
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    authKeyFile = config.sops.secrets.tailscale_key.path;
    extraUpFlags = [ "--ssh" ];
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # ── Actaul Budget ─────────────────────────────────────────────────────────
  services.actual = {
    enable = true;
    openFirewall = true;
    settings = {
      port = 5006;
    };
  };

  # ── Uptime Kuma ───────────────────────────────────────────────────────────
  services.uptime-kuma = {
    enable = true;
    settings = {
      PORT = "3001";
    };
  };

  # ── NFS ───────────────────────────────────────────────────────────────────
  boot.supportedFilesystems = [ "nfs" ];
  services.rpcbind.enable = true;

  fileSystems."/mnt/nas/media" = {
    device = "192.168.1.117:/volume2/Data";
    fsType = "nfs";
    options = [ "nfsvers=3" "soft" "x-systemd.automount" "x-systemd.idle-timeout=600" "_netdev" ];
  };

  fileSystems."/mnt/nas/immich" = {
    device = "192.168.1.117:/volume2/Immich";
    fsType = "nfs";
    options = [ "nfsvers=3" "hard" "x-systemd.automount" "x-systemd.idle-timeout=600" "_netdev" ];
  };

  fileSystems."/mnt/nas/paperless" = {
    device = "192.168.1.117:/volume2/Paperless";
    fsType = "nfs";
    options = [ "nfsvers=3" "hard" "x-systemd.automount" "x-systemd.idle-timeout=600" "_netdev" ];
  };

  # ── Firewall ──────────────────────────────────────────────────────────────
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
}
