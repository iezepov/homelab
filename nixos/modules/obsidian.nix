{ config, pkgs, lib, ... }:

# Self-hosted Obsidian LiveSync backend.
#
# CouchDB (server) + Caddy (TLS via the existing *.lab.baddog.ch wildcard cert) + a nightly
# dump of the database to the NAS. CouchDB itself listens on 127.0.0.1 only: the tailnet
# reaches it exclusively through Caddy at https://obsidian.lab.baddog.ch — never the LAN and
# never the public internet.
#
# The server configuration mirrors upstream's conf/local.ini
# (github.com/vrtmrz/self-hosted-livesync-server). Those exact settings are what the Obsidian
# LiveSync plug-in and its headless CLI expect; do not "tidy" them without checking
# docs/setup_own_server.md first.
#
# NOT declarative, by design: the database itself, the non-admin sync account and LiveSync's
# database-version document are provisioned once, by hand, with upstream's own tooling
# (utils/couchdb/couchdb-init.sh, then curl for the account + _security). On a fresh box,
# repeat those two steps and let a client re-sync its local vault copy.
let
  dbName = "obsidian-vault";
  adminPassFile = config.sops.secrets.obsidian_couch_admin_pass.path;
  backupDir = "/mnt/nas/obsidian/backups";
in
{
  # The CouchDB admin password never enters the nix store: sops renders the [admins] section
  # into a file only the couchdb user can read, and the module takes it as an extra config
  # file (the documented way to set the admin without a store leak).
  sops.secrets.obsidian_couch_admin_pass = {
    owner = "couchdb";
    group = "couchdb";
  };

  sops.templates."couchdb-admins.ini" = {
    owner = "couchdb";
    group = "couchdb";
    content = ''
      [admins]
      admin = ${config.sops.placeholder.obsidian_couch_admin_pass}
    '';
  };

  services.couchdb = {
    enable = true;
    bindAddress = "127.0.0.1";
    extraConfigFiles = [ config.sops.templates."couchdb-admins.ini".path ];
    extraConfig = {
      couchdb = {
        single_node = true;
        max_document_size = 50000000;
      };
      chttpd = {
        require_valid_user = true;
        max_http_request_size = 4294967296;
      };
      chttpd_auth.require_valid_user = true;
      httpd = {
        enable_cors = true;
        "WWW-Authenticate" = ''Basic realm="couchdb"'';
      };
      cors = {
        origins = "app://obsidian.md,capacitor://localhost,http://localhost";
        credentials = true;
        headers = "accept, authorization, content-type, origin, referer";
        methods = "GET, PUT, POST, HEAD, DELETE";
        max_age = 3600;
      };
    };
  };

  # Nightly dump of the whole database to the NAS. The vault is encrypted client-side
  # (E2EE), so these archives are ciphertext. `_local` checkpoint documents are not part of
  # _all_docs — a restore re-reads the vault from a client instead of failing.
  systemd.services.obsidian-couch-backup = {
    description = "Dump the Obsidian LiveSync CouchDB database to the NAS";
    serviceConfig.Type = "oneshot";
    path = with pkgs; [ bash curl coreutils gzip findutils ];
    script = ''
      set -euo pipefail
      base=http://127.0.0.1:5984
      dest=${lib.escapeShellArg backupDir}
      pass=$(cat ${lib.escapeShellArg adminPassFile})
      mkdir -p "$dest"
      stamp=$(date -u +%Y%m%dT%H%M%SZ)
      curl -fsS --max-time 900 -u "admin:$pass" \
        "$base/${dbName}/_all_docs?include_docs=true&attachments=true" \
        | gzip -9 > "$dest/.tmp-$stamp.json.gz"
      mv "$dest/.tmp-$stamp.json.gz" "$dest/${dbName}-$stamp.json.gz"
      # keep the 14 newest dumps
      ls -1t "$dest"/${dbName}-*.json.gz | tail -n +15 | xargs -r rm -f
      echo "dumped ${dbName}-$stamp.json.gz ($(du -h "$dest/${dbName}-$stamp.json.gz" | cut -f1))"
    '';
  };

  systemd.timers.obsidian-couch-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00";
      Persistent = true;
    };
  };
}
