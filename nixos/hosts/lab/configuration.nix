{ config, pkgs, ... }:

# This is the top-level config for the "lab" host.
# It's intentionally thin — it just sets the hostname and imports modules.
# All actual config lives in modules/ so it stays organized as we add services.

{
  imports = [
    # Generated automatically on the machine via `nixos-generate-config`.
    # Contains disk layout, filesystems, kernel modules for your specific VM.
    # You'll generate this in place — see the migration guide below.
    ./hardware-configuration.nix

    # Our modules (we'll add more here as we migrate services)
    ../../modules/base.nix
  ];

  networking.hostName = "lab";

  boot.loader.grub.devices = [ "/dev/sda" ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/afbdac41-286c-4e79-b479-a571c9e3f29b";
    fsType = "ext4";
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/dd6280da-e49e-4a4e-b183-87e32c7aa314"; }
  ];

  # This value pins certain stateful defaults (e.g. /etc/passwd format).
  # Set it once to the NixOS version you installed with, then never change it.
  # It does NOT prevent upgrading nixpkgs — it's purely for backwards compat.
  system.stateVersion = "25.05";
}
