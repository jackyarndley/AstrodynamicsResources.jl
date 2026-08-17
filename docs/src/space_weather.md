# Space weather

Space-weather products are rolling operational inputs used for atmospheric-density modelling, drag prediction and environmental context. The catalogue currently includes GFZ Kp/Ap and F10.7 products [GFZSpaceWeather](@cite), NOAA SWPC F10.7, planetary K-index and forecast feeds [NOAASWPC](@cite), SILSO sunspot numbers [SILSO](@cite), and the CelesTrak combined space-weather file [CelesTrakSpaceData](@cite).

Like EOP, these resources use `Scratch.jl` and are not frozen into immutable data releases.

```julia
using AstrodynamicsResources

kp_ap = only(resource_paths(:gfz_kp_ap))
f107 = only(resource_paths(:noaa_swpc_f107))
forecast = only(resource_paths(:noaa_swpc_45_day_forecast))
```

The refresh cadence is resource-specific. Fast-changing geomagnetic products use shorter TTLs than daily sunspot or forecast products. Inspect the local state without triggering a download with `resource_status`:

```julia
resource_status(:gfz_kp_ap)
resource_status(:noaa_swpc_planetary_k)
```

Use `refresh!` only when the application needs an explicit freshness boundary. Normal `resource_paths` calls already perform conditional refreshes when the configured TTL has expired.
