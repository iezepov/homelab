{ config, pkgs, ... }:

# Base system configuration: bootloader, user, SSH, locale, NFS mounts.
# Everything a bare NixOS install needs before any services are added.

{
  # ── Bootloader ────────────────────────────────────────────────────────────
  # GRUB is standard for Proxmox VMs (BIOS boot by default).
  # hardware-configuration.nix will set the correct device (e.g. /dev/sda).
  boot.loader.grub.enable = true;

  # ── Locale & timezone ─────────────────────────────────────────────────────
  time.timeZone = "Europe/Zurich";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Networking ────────────────────────────────────────────────────────────
  # networkd/DHCP — Proxmox VMs get an IP via DHCP by default.
  # We'll add a static IP or rely on DHCP reservation on your router.
  networking.useDHCP = true;

  # ── User ──────────────────────────────────────────────────────────────────
  # NixOS manages users declaratively. The user's password/keys are set here,
  # not via `passwd` or `adduser` — those changes would be lost on next rebuild.
  users.users.baddog = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # wheel = can use sudo
    # Paste your public SSH key(s) here.
    # The private key never touches this file — only the public key.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEOdHCXMy6xXALJZWwHCQj5iUqK/YxLoR3nOq7KjijZE ilya@baddog.ch"
    ];
  };

  # Allow wheel users to sudo without a password (convenient for a homelab).
  # Remove this line if you prefer to type your password.
  security.sudo.wheelNeedsPassword = false;

  # ── SSH ───────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # keys only
      PermitRootLogin = "no";
    };
  };
  networking.firewall.allowedTCPPorts = [ 22 ];

  # ── Base packages ─────────────────────────────────────────────────────────
  # Only tools you want available system-wide. Keep this list short.
  # Per-user packages go in home-manager; service-specific ones go in their module.
  environment.systemPackages = with pkgs; [
    git
    vim
    htop
    curl
    wget
    nfs-utils  # nfs client tools (mount.nfs etc.)
  ];

  # ── NFS ───────────────────────────────────────────────────────────────────
  # Enable NFS client support in the kernel + rpcbind daemon.
  boot.supportedFilesystems = [ "nfs" ];
  services.rpcbind.enable = true;

  # NFS mounts from Synology NAS (192.168.1.117).
  #
  # x-systemd.automount  → only mount when first accessed (saves boot time)
  # x-systemd.idle-timeout=600 → unmount after 10 min of inactivity
  # nfsvers=3            → your NAS is currently configured with NFSv3
  # soft                 → don't hang forever if NAS is unreachable at boot
  fileSystems."/mnt/nas/media" = {
    device = "192.168.1.117:/volume2/Data";
    fsType = "nfs";
    options = [ "nfsvers=3" "soft" "x-systemd.automount" "x-systemd.idle-timeout=600" "_netdev" ];
  };

  fileSystems."/mnt/nas/immich" = {
    device = "192.168.1.117:/volume2/Immich/library";
    fsType = "nfs";
    options = [ "nfsvers=3" "soft" "x-systemd.automount" "x-systemd.idle-timeout=600" "_netdev" ];
  };

  fileSystems."/mnt/nas/paperless" = {
    device = "192.168.1.117:/volume2/Paperless";
    fsType = "nfs";
    options = [ "nfsvers=3" "soft" "x-systemd.automount" "x-systemd.idle-timeout=600" "_netdev" ];
  };

  # ── Firewall ──────────────────────────────────────────────────────────────
  networking.firewall.enable = true;
  # Service modules will open their own ports — we don't hard-code them here.
}
