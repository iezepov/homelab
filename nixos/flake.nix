{
  description = "baddog homelab NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, sops-nix, vpn-confinement, ... }:
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
        ];
      };
    };
}
