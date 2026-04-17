{ config, pkgs, ... }:

# This is the top-level config for the "ubuntu" host.
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

  networking.hostName = "ubuntu";

  boot.loader.grub.device = "/dev/sda";

  # This value pins certain stateful defaults (e.g. /etc/passwd format).
  # Set it once to the NixOS version you installed with, then never change it.
  # It does NOT prevent upgrading nixpkgs — it's purely for backwards compat.
  system.stateVersion = "25.05";
}
