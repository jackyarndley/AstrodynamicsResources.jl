# Gravity models

Gravity-model resources are raw spherical-harmonic coefficient products suitable for downstream force-model implementations. The release family deliberately uses the generic name **Gravity Models** rather than “Geopotential”, because it covers both terrestrial and lunar fields.

The Earth set currently includes GGM05C and GOCO06s from ICGEM/GFZ [ICGEM](@cite) [GOCO06s](@cite). The lunar set uses the authoritative NASA PDS GRAIL LGRS Reduced Data Record [GRAILGravityRDR](@cite), including the JPL GL and GSFC GRGM solution families. GL0660B is the published degree/order-660 primary-mission JPL field [KonoplivGL0660B](@cite). PDS released the degree/order-1800 GL1800F and GL1800F_ME products on 31 March 2025.

```julia
using AstrodynamicsResources

# Earth
models = resource_paths(:earth_gravity_standard)

# Established JPL GRAIL field
lunar = only(resource_paths(:lunar_gravity_standard))

# New high-degree JPL fields
high_degree = resource_paths(:lunar_gravity_high_degree)

# All primary GRAIL spherical-harmonic products in the catalogue
all_grail = resource_paths(:lunar_gravity_grail)
```

The ICGEM Earth products use `.gfc`; the GRAIL products retain the original PDS SHADR ASCII coefficient tables (`*_sha.tab`) together with their PDS4 XML metadata labels. AstrodynamicsResources.jl returns paths and does not evaluate the spherical-harmonic expansion.

The GRAIL catalogue includes JPL GL0420A, GL0660B, GL0900C, GL0900D, GL1500E, GL1800F and GL1800F_ME, plus GSFC GRGM660PRIM, GRGM900C, GRGM1200A, GRGM1200B, the special GRGM1200B Lambda1 solution, and GRGM1200L. Bouguer products are intentionally excluded because they are derived anomaly products rather than alternate gravitational-potential solutions.

```julia
list_resources(category = :gravity)       # Earth fields
list_resources(category = :lunar_gravity) # GRAIL fields
bundle(:lunar_gravity_grail_jpl)
bundle(:lunar_gravity_grail_gsfc)
```

All immutable Earth and lunar gravity-model assets are routed to `resources-gravity-models`. Model-specific provenance, licensing and citation metadata remain attached to each resource.
