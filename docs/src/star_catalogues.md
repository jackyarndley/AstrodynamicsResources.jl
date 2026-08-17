# Star catalogues

The library provides raw FK5, Hipparcos and Tycho-2 catalogue files from CDS/VizieR and ESA sources [CDSVizieR](@cite). These are path resources only: AstrodynamicsResources.jl does not parse the fixed-width records.

The catalogue provenance follows the original publications for FK5 [FK51988](@cite), Hipparcos [Hipparcos1997](@cite), and Tycho-2 [Tycho22000](@cite).

```julia
using AstrodynamicsResources

fk5 = resource_paths(:fk5)
hipparcos = resource_paths(:hipparcos)
tycho2 = resource_paths(:tycho2)
all_stars = resource_paths(:star_catalogues)
```

Tycho-2 is distributed upstream as 20 ordered gzipped parts plus its ReadMe; `resource_paths(:tycho2)` preserves that order. The library deliberately does not concatenate or reinterpret the source archive.

Immutable star-catalogue assets are routed to `resources-star-catalogues`.
