# AstrodynamicsResources.jl

[![Documentation](https://github.com/jackyarndley/AstrodynamicsResources.jl/actions/workflows/docs.yml/badge.svg)](https://jackyarndley.github.io/AstrodynamicsResources.jl/)
[![SciML Code Style](https://img.shields.io/static/v1?label=code%20style&message=SciML&color=9558b2&labelColor=389826)](https://github.com/SciML/SciMLStyle)

**[Documentation](https://jackyarndley.github.io/AstrodynamicsResources.jl/)**

`AstrodynamicsResources.jl` provides lazy local paths to standard
astrodynamics data files. It manages data; it does not load SPICE kernels,
propagate orbits, evaluate gravity fields, or interpret Earth-orientation and
space-weather products.

```julia
using AstrodynamicsResources

de440s = only(resource_paths(:de440s))
de441 = resource_paths(:de441)
moon_pa = resource_paths(:moon_de440_pa)
uranus = resource_paths(:uranus_satellites)
gravity = only(resource_paths(:ggm05c))
eop = only(resource_paths(:iers_finals2000a))
```

Immutable files use lazy Julia artifacts. Rolling products use a locked,
conditional, atomic `Scratch.jl` cache. Importing, listing, searching, and
inspecting bundles never accesses the network.

## Adding a resource

Edit [`catalog/Resources.toml`](catalog/Resources.toml) and add:

```toml
[[resource]]
name = "example"
url = "https://authoritative.example/data/example.dat"
```

That is the complete required declaration. For a changing upstream file, add
`live = true`. Optional `ttl`, `filename`, `mirrors`, `metadata_url`,
`category`, and `provider` fields exist only for exceptions.

License terms are resolved from the provider-level `[licenses]` table; add
`license` and `license_url` only to override the provider default.

After the declaration reaches `main`, the resource-cache workflow finds entries
that are not published, downloads and validates the source, creates a
deterministic `example.tar.gz`, uploads it without overwriting existing bytes,
and opens a PR containing the generated `ResourceLock.toml` and
`Artifacts.toml` changes. Source downloads are cached between workflow runs and
package releases.

The outer release asset is named for the resource (`de440s.tar.gz`). Inside it,
the original upstream filename and bytes are preserved (`data/de440s.bsp`),
alongside `provenance.toml`. This keeps the release readable without pretending
that a compressed archive is itself a `.bsp`, `.gfc`, or `.bds` file.

Adding a declaration is also an assertion that its content may be redistributed
under the upstream terms. Package code is MIT licensed; scientific data retain
their provider terms. This project is not affiliated with NASA, JPL, NAIF,
IERS, GFZ, NOAA, ICGEM, SILSO, or CelesTrak.

## Included families

- DE430, DE431, DE432s, DE435, DE438, DE440/DE440s, DE441, and DE442/DE442s
- natural-moon SPKs for Mars, Jupiter, Saturn, Uranus, Neptune, and Pluto
- NAIF constants, frames, leap seconds, and lunar DE440 orientation
- GOCO06s and GGM05C spherical-harmonic gravity coefficient files
- selected NAIF DSK shape models
- FK5, Hipparcos, and Tycho-2 star catalogues with their CDS ReadMe files
- live IERS, GFZ, NOAA SWPC, SILSO, CelesTrak, and rolling NAIF products

DE431 and DE441 are split into their two official NAIF files and exposed as
ordered bundles. No artificial Earth-satellite or spacecraft kernels are
included.

## Licensing

Every resource records its terms in `catalog/Resources.toml`: a provider-level
`[licenses]` default, or an explicit `license`/`license_url` override. Terms
are visible in `resource`, persisted in `ResourceLock.toml`, written into
each archive's `provenance.toml`, and listed in the resource reference.

| Provider | Terms |
|:---|:---|
| NAIF | Redistribution permitted only for unmodified kernels (NAIF Rules Regarding Use of SPICE) |
| IERS | Free use with acknowledgement |
| GFZ, ICGEM | CC BY 4.0; attribution mandatory |
| NOAA SWPC | Public domain (U.S. government work) |
| SILSO | CC BY-NC 4.0 (non-commercial) |
| CelesTrak | Freely available; credit CelesTrak and respect its usage policy |
| CDS, ESA | Cite catalogue authors/publisher; free use with acknowledgement |

Package code is MIT licensed; scientific data retain their provider terms.

## Offline operation

```julia
ENV["ASTRODYNAMICS_RESOURCES_OFFLINE"] = "true"
cached = only(resource_paths(:iers_c04; stale_ok=true))
```

See the documentation for TTL overrides, cache status, verification, bundles,
and the complete resource reference.
