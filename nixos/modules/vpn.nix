{ config, pkgs, ... }:

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

    openVPNPorts = [{ port = 60601; protocol = "both"; }];
  };

  # ── ProtonVPN NAT-PMP port renewal ───────────────────────────────────────
  # Renews the NAT-PMP lease every 45s (lease expires at 60s) and keeps
  # qBittorrent's listening port in sync via its API.
  systemd.services.protonvpn-port-forward = {
    description = "ProtonVPN NAT-PMP port renewal";
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    path = [ pkgs.libnatpmp pkgs.curl pkgs.gnugrep ];
    script = ''
      GATEWAY="10.2.0.1"
      UDP_OUT=$(natpmpc -a 1 0 udp 60 -g "$GATEWAY" 2>&1)
      natpmpc -a 1 0 tcp 60 -g "$GATEWAY" > /dev/null 2>&1
      PORT=$(echo "$UDP_OUT" | grep -oP 'Mapped public port \K[0-9]+' || true)

      if [ -z "$PORT" ]; then
        echo "NAT-PMP: failed to get port" >&2
        exit 1
      fi

      echo "NAT-PMP: assigned port $PORT"
      curl -sf -X POST http://localhost:8081/api/v2/app/setPreferences \
        --data-urlencode "json={\"listen_port\":$PORT}" \
        && echo "qBittorrent listening port updated to $PORT" \
        || echo "Warning: could not update qBittorrent port" >&2
    '';
  };

  systemd.services.protonvpn-port-forward.vpnConfinement = {
    enable = true;
    vpnNamespace = "wg";
  };

  systemd.timers.protonvpn-port-forward = {
    wantedBy = [ "timers.target" ];
    description = "Renew ProtonVPN NAT-PMP lease every 45s";
    timerConfig = {
      OnBootSec = "20s";
      OnUnitActiveSec = "45s";
    };
  };
}
