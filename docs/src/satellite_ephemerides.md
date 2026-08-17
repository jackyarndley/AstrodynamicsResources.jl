# Satellite ephemerides

Satellite ephemerides in this library are primarily **natural-satellite** SPICE kernels: Mars, Jupiter, Saturn, Uranus, Neptune and Pluto systems, plus TNO satellite-system ephemerides. These are sourced from the active NAIF generic satellite and TNO collections [NAIFGenericKernels](@cite).

The bundles preserve complementary solutions where useful instead of assuming that the numerically largest kernel version supersedes every other solution. Extended-range kernels are kept in separate bundles so normal workflows do not materialise multi-gigabyte data unnecessarily.

```julia
using AstrodynamicsResources

jupiter = resource_paths(:jupiter_satellites)
saturn = resource_paths(:saturn_satellites)
uranus = resource_paths(:uranus_satellites)
neptune = resource_paths(:neptune_satellites)

# Explicitly opt into the much larger extended-range products.
saturn_xl = resource_paths(:saturn_satellites_extended)
```

TNO system kernels can be queried independently:

```julia
tnos = list_resources(category = :tno_ephemeris)
triton_xl = only(resource_paths(:neptune_triton_extended))
```

Immutable assets in this family are routed to `resources-satellite-ephemerides`.
