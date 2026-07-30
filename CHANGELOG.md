# Changelog

## 0.1.1 - Unreleased

- Audited all immutable catalogue entries against the NAIF kernel
  redistribution policy and recorded the unmodified-kernel condition and
  policy URL.
- Added resumable, digest-indexed upstream source caching and strict
  associated-file digest verification for immutable builds.
- Consolidated immutable archives under the non-latest `resources-v1` release;
  private release URLs deliberately remain unbound pending compatible hosting.
- Applied a 256 MiB active-resource limit and moved 26 oversized satellite SPKs
  to a machine-readable candidate catalogue.
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
