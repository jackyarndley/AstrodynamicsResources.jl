# Changelog

## 0.1.0 - Unreleased

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
