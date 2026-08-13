{
  description = "baddog homelab NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
    pi = {
      url = "github:lukasl-dev/pi.nix";
    };
  };

  outputs = { self, nixpkgs, sops-nix, vpn-confinement, pi, ... }: {
    nixosConfigurations.lab = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        sops-nix.nixosModules.sops
        vpn-confinement.nixosModules.default
        pi.nixosModules.default
      ];
    };
  };
}
