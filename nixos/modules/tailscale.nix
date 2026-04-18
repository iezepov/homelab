{ config, pkgs, ... }:

{
  services.tailscale = {
    enable = true;
    # Opens the required firewall port (UDP 41641) automatically.
    # useRoutingFeatures = "both" enables exit node + subnet routing if needed later.
    useRoutingFeatures = "client";
  };

  # Allow Tailscale through the firewall.
  # The module opens UDP 41641 itself, but we need to trust the tailscale0 interface
  # so services bound to it are reachable from other Tailscale nodes.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
