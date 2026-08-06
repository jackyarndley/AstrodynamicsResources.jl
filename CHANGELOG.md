# Changelog

## Unreleased

- Added FK5, Hipparcos, and Tycho-2 star catalogues with CDS ReadMe files and
  a `star_catalogues` bundle.
- Recorded license terms for every resource through provider-level
  `[licenses]` defaults; terms now appear in `resource_info`, lock entries,
  archive provenance, and the generated resource reference.
- Consolidated resource tooling into `scripts/catalog.jl` subcommands
  (`add`, `validate`, `scan`, `uncached`, `build`, `update-lock`).
- Replaced `resource_path` and `materialize` with a single `resource_paths`
  API that always returns an ordered vector of local paths.
- Added multi-file resource declarations (`[[resource.files]]`) for upstream
  products split across several files; Tycho-2 is now its 20 CDS parts plus
  ReadMe.
- Fixed the FK5 source to CDS catalogue I/149A (`catalog.gz`).

## 0.1.0 - 2026-08-03

- Added lazy Julia artifacts for 50 immutable astrodynamics resources and
  scratch caching for 12 rolling products.
- Added planetary ephemerides through DE442, including the two-part DE431 and
  DE441 products; natural-moon kernels include the
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
