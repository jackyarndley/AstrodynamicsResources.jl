# AstrodynamicsResources.jl

AstrodynamicsResources.jl is a lazy path provider for astrodynamics data. It returns local paths to authoritative data products without interpreting the files or altering global SPICE state.

Immutable resources are verified Julia artifacts. Rolling products such as Earth Orientation Parameters (EOP) and space-weather feeds use `Scratch.jl` with conditional requests, configurable TTLs, atomic replacement, and stale-cache fallback. Catalogue inspection is always offline.

## Resource families

The documentation and immutable data releases are organised by scientific use rather than by file extension:

- [General ephemerides](general_ephemerides.md) — DE planetary ephemerides, station kernels, Lagrange-point kernels, asteroid and comet SPKs.
- [Satellite ephemerides](satellite_ephemerides.md) — natural-satellite and TNO-system ephemerides.
- [Earth Orientation Parameters](earth_orientation.md) — rolling IERS/CelesTrak EOP products and the current high-precision Earth PCK.
- [Space weather](space_weather.md) — Kp/Ap, F10.7, sunspot and forecast products.
- [Star catalogues](star_catalogues.md) — FK5, Hipparcos and Tycho-2.
- [Geopotential models](geopotential_models.md) — spherical-harmonic gravity coefficient files.
- [Planet textures](planet_textures.md) — Solar System Scope 2k textures selected from the Simple Space Data mirror registry.
- [Reference kernels and shape models](reference_data.md) — SPICE constants, orientation kernels and DSK shape models.

The complete generated table is available in the [resource catalogue](resources.md).

## Immutable release layout

New immutable resources are cached into stable data-family releases rather than the package source release:

| Family | Release tag |
|:---|:---|
| General ephemerides | `resources-ephemerides` |
| Satellite ephemerides | `resources-satellite-ephemerides` |
| Star catalogues | `resources-star-catalogues` |
| Geopotential models | `resources-geopotential` |
| Planet textures | `resources-textures` |
| Reference kernels | `resources-reference` |
| Shape models | `resources-shape-models` |

The original `v0.1.0` resource release remains a valid legacy source for already locked artifacts. EOP and space-weather products are deliberately **not** frozen into releases because they are rolling operational data.

## Basic usage

Catalogue operations never download:

```julia
using AstrodynamicsResources

resource(:de440s)
list_resources(category = :gravity)
find_resources("moon pa")
bundle(:planet_textures)
```

Path operations explicitly permit lazy materialisation:

```julia
de440s = only(resource_paths(:de440s))
eop = only(resource_paths(:iers_finals2000a))
earth = only(resource_paths(:texture_earth_day))
```

`resource_paths` always returns a vector, preserves bundle order, and downloads only missing members. Use `only(resource_paths(id))` for a resource with exactly one primary file.

The SPICE resources are sourced from NAIF's generic-kernel archive [NAIFGenericKernels](@cite). Provider-specific attribution and licensing are recorded on every resource and shown in the generated catalogue.
