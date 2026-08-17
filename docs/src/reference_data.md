# Reference kernels and shape models

Some fixed resources do not belong naturally to an ephemeris or environmental-data family. These include SPICE leap-second, constants, frame and orientation kernels, together with DSK shape models from the NAIF generic-kernel archive [NAIFGenericKernels](@cite).

The lunar DE440 orientation bundle keeps the binary principal-axis PCK, frame definitions and association kernels explicit so the package never makes a hidden global SPICE-frame choice.

```julia
using AstrodynamicsResources

core = resource_paths(:naif_core)
lunar_pa = resource_paths(:moon_de440_pa)
lunar_me = resource_paths(:moon_de440_me)
```

Shape models can be selected independently by resource ID:

```julia
eros = only(resource_paths(:eros_near_msi_512q))
itokawa = only(resource_paths(:itokawa_hayabusa_amica_512q))
phobos = only(resource_paths(:phobos512))
```

Reference kernels are routed to `resources-reference`; DSK geometry assets are routed to `resources-shape-models`.
