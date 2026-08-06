# AstrodynamicsResources.jl

AstrodynamicsResources.jl is a lazy path provider for astrodynamics data. It
does not interpret the files or alter global SPICE state.

Immutable resources are public, verified Julia artifacts. Rolling resources
use `Scratch.jl`, conditional requests, configurable TTLs, atomic replacement,
and stale-cache fallback. Catalogue inspection is always offline.

The hand-maintained catalogue is deliberately small: every immutable resource
requires only a name and authoritative URL. Hashes, archive identity, size, and
Julia artifact bindings live in generated files. Release archives use names
such as `de440s.tar.gz` and contain the unchanged upstream file at
`data/de440s.bsp`.

DE440s is the recommended compact planetary default. Full DE440, two-part
DE431 and DE441, and the newer DE442/DE442s pair remain separate resources.
Planetary-satellite entries describe natural moons, not artificial satellites
or spacecraft.

GOCO06s and GGM05C provide original ICGEM `.gfc` spherical-harmonic
coefficients. This package returns their paths but does not evaluate them.

## Using resources

Catalogue operations never download:

```julia
using AstrodynamicsResources

resource(:de440s)
list_resources(category=:gravity)
find_resources("moon pa")
bundle(:moon_de440_pa)
```

Path operations explicitly permit lazy materialization:

```julia
de440s = only(resource_paths(:de440s))
de441 = resource_paths(:de441)
lunar_pa = resource_paths(:moon_de440_pa)
eop = only(resource_paths(:iers_finals2000a))
```

`resource_paths` is the single path accessor: it always returns a vector,
preserves bundle order, and downloads only missing members. Use
`only(resource_paths(id))` for a resource with exactly one primary file. Large
SPKs and DSKs can consume gigabytes, so inspect their size before materializing.

## Lunar DE440 orientation

- `moon_pa_de440` is the binary principal-axis PCK.
- `moon_de440_frames` defines the PA and mean-Earth frame relationships.
- `moon_assoc_pa` selects the principal-axis association.
- `moon_assoc_me` selects the mean-Earth association.

The binary PCK and frame kernel are both required. Users should not normally
load both association kernels. This package makes no global choice and never
loads SPICE kernels:

```julia
pa = resource_paths(:moon_de440_pa)
me = resource_paths(:moon_de440_me)
```

## Star catalogues

- `fk5` — FK5 Part I fundamental catalogue (1,535 stars; VizieR I/149A).
- `hipparcos` — Hipparcos main catalogue (118,218 entries; VizieR I/239).
- `tycho2` — Tycho-2 catalogue (2,539,913 stars; VizieR I/259).

Each entry contains the original CDS data file and its ReadMe:

```julia
fk5 = only(resource_paths(:fk5))          # the catalog.gz data file
stars = resource_paths(:star_catalogues)  # all data files and ReadMes
```

These are raw catalogue files returned as paths; this package does not parse
them. License terms for each catalogue are recorded in the catalogue and shown
by `resource`. Tycho-2 is distributed by CDS as 20 gzipped parts, so
`resource_paths(:tycho2)` returns those 20 ordered parts plus its ReadMe.

## Offline operation and integrity

Set `ASTRODYNAMICS_RESOURCES_OFFLINE=true` to prohibit network access.
Installed artifacts continue to work, and cached live products can be returned
with `stale_ok=true`.

```julia
status = resource_status(:iers_finals2000a)
refresh!(:iers_finals2000a)
verify_resource(:iers_finals2000a)
clear_resource!(:iers_finals2000a)
```

Live downloads use conditional requests, temporary files, atomic replacement,
and stale-cache fallback. Immutable SHA-256 and Julia tree hashes are recorded
in `ResourceLock.toml` and `Artifacts.toml`, while release assets keep readable
filenames.

## Public API

```@autodocs
Modules = [AstrodynamicsResources]
Private = false
Order = [:type, :function]
```
