{ ... }:

{
  # ── Immich ───────────────────────────────────────────────────────────────
  services.immich = {
    enable = true;
    mediaLocation = "/mnt/nas/immich/library";
    accelerationDevices = [ "/dev/dri/renderD128" ];
    host = "0.0.0.0";
  };

  # ── Paperless-ngx ────────────────────────────────────────────────────────
  services.paperless = {
    enable = true;
    mediaDir = "/mnt/nas/paperless/media";
    consumptionDir = "/mnt/nas/paperless/consume";
    settings = {
      PAPERLESS_OCR_LANGUAGE = "eng+deu+rus";
      PAPERLESS_URL = "https://paperless.lab.baddog.ch";
    };
  };

  # ── Actual Budget ────────────────────────────────────────────────────────
  services.actual = {
    enable = true;
    settings.port = 5006;
  };

  # ── Uptime Kuma ──────────────────────────────────────────────────────────
  services.uptime-kuma = {
    enable = true;
    settings.PORT = "3001";
  };
}
