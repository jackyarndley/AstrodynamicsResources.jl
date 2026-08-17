# Earth Orientation Parameters

Earth Orientation Parameters (EOP) are operational data and are therefore handled differently from fixed kernels. The library exposes rolling IERS products, a CelesTrak EOP feed, and the current NAIF high-precision Earth orientation PCK. IERS is the authoritative service for Earth-rotation and reference-system products [IERSData](@cite); CelesTrak provides a convenient operational compilation [CelesTrakSpaceData](@cite).

These resources use the `Scratch.jl` backend rather than immutable GitHub release assets. A local cached copy is refreshed according to its TTL, conditional HTTP requests are used when possible, and stale data may be returned when explicitly allowed.

```julia
using AstrodynamicsResources

finals = only(resource_paths(:iers_finals2000a))
c04 = only(resource_paths(:iers_c04))
status = resource_status(:iers_finals2000a)
```

Force a refresh or verify the cached copy when required:

```julia
refresh!(:iers_finals2000a)
verify_resource(:iers_finals2000a)
```

Set `ASTRODYNAMICS_RESOURCES_OFFLINE=true` to prohibit network access. Cached EOP data remain usable offline subject to the stale-data policy.

EOP resources are intentionally **not** assigned to a versioned resource release: a release snapshot would look reproducible while quietly becoming obsolete for operational work.
