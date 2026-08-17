# General ephemerides

The general-ephemeris family contains planetary DE kernels together with non-satellite SPKs used in mission design: ground-station ephemerides, Lagrange-point kernels, asteroid collections and comet ephemerides. The planetary and small-body SPKs come from NASA NAIF's generic-kernel archive [NAIFGenericKernels](@cite).

DE440s is the recommended compact default for ordinary modern-epoch planetary work. Full DE440, the two-part long-range DE431 and DE441 solutions, and DE442/DE442s remain independently selectable rather than being silently substituted.

```julia
using AstrodynamicsResources

compact = only(resource_paths(:de440s))
full = only(resource_paths(:de440))
long_range = resource_paths(:de441)
lagrange = resource_paths(:earth_lagrange_de441)
stations = resource_paths(:dsn_stations)
asteroids = only(resource_paths(:asteroids_300))
```

Immutable assets in this family are routed to `resources-ephemerides-v1`. Existing artifacts whose lock still points at the legacy `v0.1.0` release remain valid.

Use `list_resources` to inspect the family without downloading anything:

```julia
vcat(
    list_resources(category = :ephemeris),
    list_resources(category = :lagrange_ephemeris),
    list_resources(category = :station_ephemeris),
    list_resources(category = :asteroid_ephemeris),
    list_resources(category = :comet_ephemeris),
)
```
