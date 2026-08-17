# API

## Querying the catalogue

Catalogue queries are offline and do not materialise resources:

```julia
using AstrodynamicsResources

resource(:de440s)
list_resources(category = :texture)
find_resources("Earth")
bundle(:planet_textures)
```

## Materialising paths

`resource_paths` is the single path accessor. It always returns a vector and preserves bundle order.

```julia
only(resource_paths(:de440s))
resource_paths(:de441)
resource_paths(:star_catalogues)
```

## Live-resource management

```julia
resource_status(:iers_finals2000a)
refresh!(:iers_finals2000a)
verify_resource(:iers_finals2000a)
clear_resource!(:iers_finals2000a)
```

## Public API reference

```@autodocs
Modules = [AstrodynamicsResources]
Private = false
Order = [:type, :function]
```
