# AstrodynamicsResources.jl

`AstrodynamicsResources.jl` is a path-oriented catalogue and lazy resource
manager for standard astrodynamics data files. It does not perform SPICE
calculations, propagate orbits, evaluate gravity fields, parse Earth-orientation
data, or modify any process-global kernel state.

```julia
using AstrodynamicsResources

resource(:de440s)                       # metadata only; no download
bundle(:moon_de440_pa)                  # ordered metadata only; no download
list_resources(category=:orientation)  # local search

eop = resource_path(:iers_finals2000a) # explicit live download/cache
```

Immutable, versioned datasets use lazy Julia artifacts. Mutable upstream
products use `Scratch.jl`, conditional HTTP requests, configurable TTLs, atomic
replacement, stale-cache fallback, and cross-process locking. Installation,
precompilation, import, catalogue inspection, search, and bundle inspection do
not download scientific data.

## Current publication state

The package framework and live-resource backend are operational. Production
immutable resources are catalogued but deliberately marked unavailable until
their licensing review, deterministic archives, release assets, SHA-256
digests, and Julia tree hashes are published. Calling `resource_path(:de440s)`
therefore gives an actionable pending-publication error instead of silently
downloading an unverified raw file. See
[`catalog/pending_builds.toml`](catalog/pending_builds.toml).

No production scientific artifact has been published from this repository.
There are no placeholder hashes or invented mirrors in `Artifacts.toml`.

## Storage model

- Artifacts are immutable, versioned, content-addressed, and always `lazy=true`.
- Live data are only downloaded or revalidated after an explicit path or
  materialization request.
- Failed live updates preserve the previous valid cache.
- `resource_paths(bundle_id)` returns flattened paths in stable consumer load
  order; the package never loads them.

DE440s is the compact recommended default for most users. Full DE440 remains a
separate resource. Reviewed older releases DE430, DE432s, DE435, and DE438 are
also catalogued for reproducibility with legacy workflows. The split DE431 and
DE441 releases are intentionally excluded because of their multi-gigabyte
sizes. No DE431 or DE441 ID or bundle exists.

## Configuration

```text
ASTRODYNAMICS_RESOURCES_OFFLINE
ASTRODYNAMICS_RESOURCES_ALLOW_STALE
ASTRODYNAMICS_RESOURCES_MIRROR
ASTRODYNAMICS_RESOURCES_TIMEOUT
ASTRODYNAMICS_RESOURCES_CACHE
ASTRODYNAMICS_RESOURCES_TTL_<RESOURCE_ID>
```

For example:

```julia
ENV["ASTRODYNAMICS_RESOURCES_OFFLINE"] = "true"
cached = resource_path(:iers_c04; stale_ok=true)
```

## Data providers and non-endorsement

Dataset metadata preserves provider attribution and citations. Package code is
MIT licensed, but scientific datasets retain their own terms. This independent
project is not affiliated with or endorsed by NASA, JPL, NAIF, IERS, GFZ,
NOAA, SILSO, CelesTrak, or any other data provider.

See the [documentation](docs/src/index.md), [contribution
guide](docs/src/contributing.md), and [changelog](CHANGELOG.md).
