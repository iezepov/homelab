# This file is generated automatically on the target machine.
# DO NOT edit manually — run this on the new NixOS VM instead:
#
#   nixos-generate-config --show-hardware-config > hardware-configuration.nix
#
# Then commit the result. It will contain the correct disk device paths,
# filesystem UUIDs, kernel modules for virtio drivers, etc.

# Placeholder — replace with real output from nixos-generate-config
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Disk and filesystem config will be filled in by nixos-generate-config.
  # The values below are examples only — yours will have real UUIDs.

  # fileSystems."/" = {
  #   device = "/dev/disk/by-uuid/XXXX-XXXX";
  #   fsType = "ext4";
  # };

  # boot.loader.grub.device = "/dev/sda";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  virtualisation.hypervGuest.enable = lib.mkDefault false;
}
