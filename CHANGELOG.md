# Changelog

## 0.1.1 - Unreleased

- Audited all immutable catalogue entries against the NAIF kernel
  redistribution policy and recorded the unmodified-kernel condition and
  policy URL.
- Added resumable, digest-indexed upstream source caching and strict
  associated-file digest verification for immutable builds.
- Consolidated immutable archives under the non-latest `resources-v1` release;
  private release URLs deliberately remain unbound pending compatible hosting.
- Simplified immutable releases to one archive asset per resource; the Julia
  tree hash is stored in the archive asset label and the archive SHA-256 remains
  available through GitHub's asset digest.
- Named each release archive after its authoritative upstream data file (for
  example, `de440s.bsp.tar.gz`) and reject duplicate or unsafe source filenames.
- Added the original ICGEM spherical-harmonic coefficient files for GOCO06s and
  GGM05C as reviewed CC BY 4.0 Earth gravity resources.
- Added exact DE442 and DE442s resources and ordered compact/full bundles.
- Clarified that satellite resources describe natural moons, restored the
  compact planetary-system selections, and added the explicitly requested
  multipart Uranus `ura184` product. Artificial-satellite and spacecraft
  kernels remain out of scope.
- Updated every GitHub Action to its current official release tag.

## 0.1.0 - 2026-07-30

- Added catalogue-only resource discovery and ordered logical bundles.
- Added dynamic lazy-artifact resolution through Julia's public artifact APIs.
- Added locked, conditional, atomic, offline-capable scratch caching.
- Added DE430, DE432s, DE435, DE438, DE440/DE440s, NAIF support,
  lunar DE440 orientation, satellite SPK, live environment and space-weather,
  and initial DSK metadata.
- Added ordered legacy ephemeris bundles for DE430, DE432s, DE435, and DE438;
  split DE431 and DE441 resources remain explicitly excluded.
- Added candidate catalogues for gravity models and unresolved geometry.
- Added deterministic discovery and artifact packaging tools.
- Established reviewed semantic aliases for the pinned lunar DE440 resources.
  Future alias changes require an explicit changelog entry.
- No production immutable artifacts have been published in this release.
