# Hermes agent (remote automation) access to this host.
#
# Deliberately conservative:
#  - the agent user is the ONLY account with passwordless sudo (baddog keeps the
#    normal password-required behaviour)
#  - the agent's sshd is a SEPARATE instance on port 2222 with its own
#    config, restricted to one user, so a mistake here cannot break port 22
{ config, pkgs, lib, ... }:

let
  agentPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA499H8Fg3QxnlNerZEs1M1i1TbM20dns8bFpDDgnSFB hermes-agent-ha";
in
{
  users.users.hermes = {
    isNormalUser = true;
    description = "Hermes agent automation";
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [ agentPubKey ];
    # Tooling for the agent's own scripts, scoped to this user's profile so the
    # system-wide package set stays as it was (jq/python3 are not in it).
    packages = with pkgs; [ jq python3 curl ];
  };

  # Root-equivalent, scoped to the agent user only.
  security.sudo.extraRules = [
    {
      users = [ "hermes" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" "SETENV" ]; } ];
    }
  ];

  # Port 22 on the tailnet is answered by Tailscale SSH (interactive check per
  # session), which no automation can use - hence a second listener.
  networking.firewall.allowedTCPPorts = [ 2222 ];

  environment.etc."ssh/sshd-hermes.conf" = {
    mode = "0644";
    text = ''
      Port 2222
      AddressFamily any
      HostKey /etc/ssh/ssh_host_ed25519_key
      AuthorizedKeysFile %h/.ssh/authorized_keys /etc/ssh/authorized_keys.d/%u
      PubkeyAuthentication yes
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
      AllowUsers hermes
      UsePAM yes
      Subsystem sftp ${pkgs.openssh}/libexec/sftp-server
      LogLevel VERBOSE
    '';
  };

  systemd.services.sshd-hermes = {
    description = "OpenSSH daemon for the Hermes agent (port 2222)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "sshd.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.openssh}/bin/sshd -D -f /etc/ssh/sshd-hermes.conf";
      Restart = "always";
      RestartSec = 2;
    };
  };
}
