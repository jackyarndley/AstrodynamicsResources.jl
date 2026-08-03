# Using resources

Catalogue operations never download:

```julia
using AstrodynamicsResources

resource(:de440s)
resource(:de430)
list_resources(category=:gravity)
list_resources(category=:orientation, body=:moon)
find_resources("moon pa")
bundle(:moon_de440_pa)
```

Path operations explicitly permit lazy materialization:

```julia
de440s = resource_path(:de440s)
de430 = resource_path(:de430)
lunar_pa = resource_paths(:moon_de440_pa)
de442 = resource_path(:de442)
eop = resource_path(:iers_finals2000a)
```

`resource_path` is only for one-primary-file resources. It throws for a bundle
or ambiguous multipart resource. `resource_paths` always returns a vector and
flattens bundle paths in stable order. Members remain separate artifacts and
only missing members materialize.

Satellite-system resources here are ephemerides for natural moons, not
artificial Earth satellites or spacecraft. For example,
`resource_paths(:uranus_satellites)` returns the three `ura184` parts in
official order.

Large SPKs and DSKs can consume gigabytes in the Julia artifact depot. Inspect
`size_bytes` and bundle membership before materializing them.
