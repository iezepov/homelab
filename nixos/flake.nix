{
  description = "baddog homelab NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
    pi = {
      url = "github:lukasl-dev/pi.nix";
    };
    omp = {
      url = "github:can1357/oh-my-pi";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, sops-nix, vpn-confinement, pi, omp, ... }:
    let
      system = "x86_64-linux";
      pkgsUnstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs-unstable.lib.getName pkg) [ "unrar" ];
      };
    in
    {
      nixosConfigurations.lab = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgsUnstable; };
        modules = [
          ./configuration.nix
          sops-nix.nixosModules.sops
          vpn-confinement.nixosModules.default
          pi.nixosModules.default
          omp.nixosModules.default
        ];
      };
    };
}
