# Using resources

Catalogue operations never download:

```julia
using AstrodynamicsResources

resource(:de440s)
resource(:de430)
list_resources(category=:gravity)
list_resources(category=:orientation, body=:moon)
find_resources("lunar principal axis")
bundle(:moon_de440_pa)
```

Path operations explicitly permit lazy materialization:

```julia
de440s = resource_path(:de440s)
de430 = resource_path(:de430)
lunar_pa = resource_paths(:moon_de440_pa)
jupiter = resource_paths(:jupiter_satellites)
eop = resource_path(:iers_finals2000a)
```

`resource_path` is only for one-primary-file resources. It throws for a bundle
or ambiguous multipart resource. `resource_paths` always returns a vector and
flattens bundle paths in stable order. Members remain separate artifacts and
only missing members materialize.

The latest-numbered satellite SPK is not automatically the best: target sets,
coverage, reconstruction, precision, range, associated frames, and size differ.
Recommendations are reviewed metadata, never lexical aliases.

Large SPKs and DSKs can consume gigabytes in the Julia artifact depot. Inspect
`size_bytes` and bundle membership before materializing them.
