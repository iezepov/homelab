{ config, ... }:

{
  # Store the full ProtonVPN WireGuard .conf as a SOPS secret
  sops.secrets.protonvpn_wg_conf = {
    mode = "0400";
  };

  vpnNamespaces.wg = {
    enable = true;
    wireguardConfigFile = config.sops.secrets.protonvpn_wg_conf.path;

    # Allow host-local services (Caddy, Arr stack) and Tailscale to reach
    # services inside the namespace at 192.168.15.1
    accessibleFrom = [
      "127.0.0.1/32"
      "100.64.0.0/10" # Tailscale
    ];

    portMappings = [
      { from = 8081; to = 8081; protocol = "tcp"; } # qBittorrent web UI
      { from = 8080; to = 8080; protocol = "tcp"; } # SABnzbd web UI
    ];

    # After getting your ProtonVPN port forwarding assignment, uncomment and set:
    # openVPNPorts = [{ port = XXXXX; protocol = "both"; }];
  };
}
