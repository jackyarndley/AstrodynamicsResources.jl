# Changelog

## 0.1.0 - 2026-08-03

- Added lazy Julia artifacts for 46 immutable astrodynamics resources and
  scratch caching for 12 rolling products.
- Added planetary ephemerides through DE442, natural-moon kernels including the
  three-part Uranus `ura184` product, lunar DE440 orientation, NAIF support
  kernels, DSK shapes, and GOCO06s/GGM05C gravity coefficients.
- Added ordered bundles, offline operation, cache freshness/status,
  verification, atomic replacement, stale fallback, and cross-process locks.
- Replaced the original verbose catalogue with `name` + `url` declarations,
  inferred metadata, and generated immutable lock/artifact files.
- Added automatic scanning, source caching, deterministic packaging, immutable
  release upload, and generated lock pull requests for new declarations.
- Consolidated package code and resource archives into the `v0.1.0` release.
  Release archives use clear resource names such as `de440s.tar.gz`; original
  upstream filenames and bytes remain inside each archive.
- Removed obsolete candidate catalogues, pending manifests, discovery reports,
  per-resource release tags, and the separate resource release workflow.
