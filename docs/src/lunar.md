# Lunar DE440 orientation

The high-precision lunar orientation is split across files with distinct roles:

- `moon_pa_de440` is the binary PCK containing DE440 principal-axis
  orientation.
- `moon_de440_frames` defines `MOON_PA`, `MOON_ME`, `MOON_PA_DE440`, and
  `MOON_ME_DE440_ME421`, including the relationship to the binary-PCK frame.
- `moon_assoc_pa` optionally selects the principal-axis association.
- `moon_assoc_me` optionally selects the mean-Earth association.

The binary PCK and frame kernel are both needed to interpret the high-precision
orientation. Users should not normally load both association kernels: each
selects a different association policy and later-loaded frame assignments can
matter to a SPICE consumer.

The package makes no global choice and calls no SPICE loading function. It only
returns stable ordered paths:

```julia
base = resource_paths(:moon_de440_orientation)
pa = resource_paths(:moon_de440_pa)
me = resource_paths(:moon_de440_me)
```

Lunar gravity is a separate scientific family and is not included in these
orientation bundles.

