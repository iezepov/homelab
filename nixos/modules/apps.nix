{ pkgs, pkgsUnstable, ... }:

{
  # ── Immich ───────────────────────────────────────────────────────────────
  services.immich = {
    # Immich 3.x, pinned from nixpkgs-unstable on purpose: 26.05 still ships
    # 2.7.5, which it flags insecure (CVE-2026-59258, CVE-2026-82272) and
    # which upstream no longer maintains. Same option also drives the
    # immich-machine-learning service.
    package = pkgsUnstable.immich;
    enable = true;
    mediaLocation = "/mnt/nas/immich/library";
    accelerationDevices = [ "/dev/dri/renderD128" ];
    host = "0.0.0.0";
  };

  users.users.immich.extraGroups = [
    "render"
    "video"
  ];

  # ── Paperless-ngx ────────────────────────────────────────────────────────
  services.paperless = {
    enable = true;
    # 26.05's paperless-ngx is not in the binary cache because its own test suite
    # fails in Hydra: test_slow_write_incomplete expects the consumer to have
    # scheduled a retry ("delay") for an incomplete file read within a fixed
    # window, which does not hold on a saturated 2-core VM ("Called 0 times").
    # 1447 of 1448 tests pass. Deselect just that timing test - the same
    # mechanism nixpkgs already uses for its own environment-dependent failures -
    # instead of skipping the whole suite with doCheck = false.
    # unstable's 3.3.0 was evaluated as an alternative (cheaper bumps) and rejected:
    # its NixOS module wraps the package (pkg.override with a tesseract5 override),
    # so the derivation actually needed is in nobody's cache - 3.3.0 would cost the
    # same from-source build with the same flaky test, only far more often, plus a
    # database migration and an unstable module on a stable release. The plain
    # package being on cache.nixos.org says nothing about the variant a module asks
    # for; check the derivation the config needs, via its narinfo.
    package = pkgs.paperless-ngx.overrideAttrs (old: {
      disabledTests = (old.disabledTests or [ ]) ++ [ "test_slow_write_incomplete" ];
    });
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
