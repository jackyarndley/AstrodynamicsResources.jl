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

The package framework and live-resource backend are operational. NAIF permits
redistribution of its kernels while they remain unmodified; the package
preserves those source bytes exactly and records the applicable terms.
Production immutable resources remain marked unavailable until their
independent SHA-256 review, deterministic archives, release assets, and Julia
tree hashes are all published to a location supported by Julia's artifact
downloader. Calling `resource_path(:de440s)` therefore gives an actionable
pending-publication error instead of silently downloading an unverified raw
file. See
[`catalog/pending_builds.toml`](catalog/pending_builds.toml).

Verified archives are attached, without overwriting, to the repository's
`resources-v1` release. Each archive uses the recognizable authoritative source
name, such as `de440s.bsp.tar.gz`; the archive remains a deterministic package
containing the original `data/de440s.bsp`. Because this repository is private,
those authenticated release URLs are not yet bound in `Artifacts.toml`:
standard Julia artifact downloads cannot authenticate to private GitHub release
assets. There are no placeholder hashes or invented mirrors.

## Storage model

- Artifacts are immutable, versioned, content-addressed, and always `lazy=true`.
- Live data are only downloaded or revalidated after an explicit path or
  materialization request.
- Failed live updates preserve the previous valid cache.
- `resource_paths(bundle_id)` returns flattened paths in stable consumer load
  order; the package never loads them.

DE440s is the compact recommended default for most users. Full DE440 remains a
separate resource. Reviewed DE430, DE432s, DE435, DE438, and current DE442/DE442s
releases are separately catalogued. The split DE431 and DE441 releases are
intentionally excluded because of their multi-gigabyte sizes. Planetary
natural-satellite ephemerides are included, with an explicit three-part Uranus
`ura184` bundle. No artificial Earth-satellite or spacecraft kernels are
catalogued.

GOCO06s and GGM05C are now reviewed Earth spherical-harmonic coefficient
resources in their original ICGEM `.gfc` format. Both upstream files state CC
BY 4.0 terms and retain their DOI citations. They remain pending immutable
publication like the kernels above; this package returns coefficient-file
paths and does not evaluate a gravity field.

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
MIT licensed, but scientific datasets retain their own terms. NAIF kernel
redistribution follows the [NAIF Rules Regarding Use of
SPICE](https://naif.jpl.nasa.gov/naif/rules.html): redistributed kernels must
remain unmodified, and acknowledgement of SPICE/NAIF/PDS and the producing
teams is encouraged. This independent project is not affiliated with or
endorsed by NASA, JPL, NAIF, IERS, GFZ, NOAA, SILSO, CelesTrak, or any other
data provider.

See the [documentation](docs/src/index.md), [contribution
guide](docs/src/contributing.md), and [changelog](CHANGELOG.md).
