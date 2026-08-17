# Geopotential models

Geopotential resources are raw spherical-harmonic coefficient files suitable for use by downstream gravity-model implementations. The catalogue currently includes GGM05C and GOCO06s from ICGEM/GFZ; ICGEM provides the authoritative model archive and metadata [ICGEM](@cite), and GOCO06s has a citable model release [GOCO06s](@cite).

AstrodynamicsResources.jl returns the `.gfc` file path and does not evaluate the spherical-harmonic expansion.

```julia
using AstrodynamicsResources

ggm05c = only(resource_paths(:ggm05c))
goco06s = only(resource_paths(:goco06s))
models = resource_paths(:earth_gravity_standard)
```

Inspect all currently catalogued coefficient sets without downloading them:

```julia
list_resources(category = :gravity)
```

Immutable geopotential-model assets are routed to `resources-geopotential`. Model-specific licensing and citation metadata remain attached to each resource.
