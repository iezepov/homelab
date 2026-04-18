{
  # A flake is NixOS's modern entry point. Think of it like package.json:
  # it declares your dependencies (inputs) and what you produce (outputs).
  # The key benefit: inputs are version-pinned in flake.lock, so builds are
  # 100% reproducible — the same flake.lock always produces the same system.

  description = "baddog homelab NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    # sops-nix lets you store secrets encrypted in git (using age keys).
    # Replaces your .env files. We'll wire this up when adding services.
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs"; # use the same nixpkgs version, not sops-nix's own
    };
  };

  outputs = { self, nixpkgs, sops-nix, ... }: {
    nixosConfigurations = {
      # "ubuntu" is the hostname. Build/deploy with:
      #   nixos-rebuild switch --flake .#ubuntu
      lab = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/lab/configuration.nix
          sops-nix.nixosModules.sops
        ];
      };
    };
  };
}
