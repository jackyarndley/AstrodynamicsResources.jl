# AstrodynamicsResources.jl

[![Documentation](https://github.com/jackyarndley/AstrodynamicsResources.jl/actions/workflows/docs.yml/badge.svg)](https://jackyarndley.github.io/AstrodynamicsResources.jl/)
[![SciML Code Style](https://img.shields.io/static/v1?label=code%20style&message=SciML&color=9558b2&labelColor=389826)](https://github.com/SciML/SciMLStyle)

**[Documentation](https://jackyarndley.github.io/AstrodynamicsResources.jl/)**

`AstrodynamicsResources.jl` provides lazy local paths to standard astrodynamics
data files. It manages data; it does not load SPICE kernels, propagate orbits,
evaluate gravity fields, or interpret Earth-orientation and space-weather
products.

```julia
using AstrodynamicsResources

de440s = only(resource_paths(:de440s))
de441 = resource_paths(:de441)
moon_pa = resource_paths(:moon_de440_pa)
uranus = resource_paths(:uranus_satellites)
gravity = only(resource_paths(:ggm05c))
eop = only(resource_paths(:iers_finals2000a))
```

Immutable files use Julia's artifact store. Rolling products use a conditional,
atomic `Scratch.jl` cache. Importing, listing, searching, and inspecting bundles
never accesses the network.

## Adding a resource

Add the minimal declaration to one of the catalogue TOML files:

```toml
[[resource]]
name = "example"
url = "https://authoritative.example/data/example.dat"
```

For a changing upstream file, add `live = true`. Optional `ttl`, `filename`,
`mirrors`, `metadata_url`, `category`, and `provider` fields exist for
exceptions. License terms are resolved from provider-level `[licenses]`
tables, with per-resource overrides when needed.

After the declaration reaches `main`, **Cache resources** checks the canonical
resource-family release. If `example.tar.gz` is already there, it verifies and
adopts that archive instead of rebuilding it. Otherwise it downloads the
upstream source, creates the deterministic archive, and uploads it without
overwriting existing bytes. Every successful resource then gets its hashes
written directly into its own declaration:

```toml
[[resource]]
name = "example"
sha256 = "..."             # authoritative upstream file
artifact_sha256 = "..."    # published example.tar.gz
git_tree_sha1 = "..."      # extracted Julia artifact tree
url = "https://authoritative.example/data/example.dat"
```

Multi-file resources put `sha256` beside each `[[resource.files]]` URL. A
`metadata_url` gets a `metadata_sha256`. Release tags, asset names, and download
URLs are derived from the resource category and name; they are not duplicated
in the catalogue.

There is no committed generated lock database. The catalogue is the source of
truth. At materialization time the package creates a tiny temporary Julia
artifact binding from the inline hashes, then uses the normal `Pkg.Artifacts`
store.

The outer release asset is named for the resource (`de440s.tar.gz`). Inside it,
the original upstream filename and bytes are preserved (`data/de440s.bsp`),
alongside `provenance.toml`.

Adding a declaration is also an assertion that its content may be redistributed
under the upstream terms. Package code is MIT licensed; scientific data retain
their provider terms. This project is not affiliated with NASA, JPL, NAIF,
IERS, GFZ, NOAA, ICGEM, SILSO, CelesTrak, or the NASA PDS.

## Included families

- JPL DE planetary ephemerides and Earth/Lagrange/station SPKs
- natural-satellite and TNO-system ephemerides
- NAIF constants, frames, leap seconds, and lunar orientation products
- Earth gravity fields including GGM05C and GOCO06s
- GRAIL lunar gravity fields including GL0660B and degree-1800 GL1800F variants
- selected NAIF DSK shape models
- FK5, Hipparcos, and Tycho-2 star catalogues
- Solar System Scope planet/sky textures
- live IERS, GFZ, NOAA SWPC, SILSO, CelesTrak, and rolling NAIF products

## Licensing

Every resource resolves its terms directly from the catalogue. Those terms are
visible in `resource`, written into each immutable archive's `provenance.toml`,
and listed in the generated resource reference.

Package code is MIT licensed; scientific data retain their provider terms.

## Offline operation

```julia
ENV["ASTRODYNAMICS_RESOURCES_OFFLINE"] = "true"
cached = only(resource_paths(:iers_c04; stale_ok=true))
```

See the documentation for TTL overrides, cache status, verification, bundles,
and the complete resource reference.
