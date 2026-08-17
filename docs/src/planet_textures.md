# Planet textures

The texture catalogue follows the set exposed by the Simple Space Data mirror [SimpleSpaceData](@cite), which in turn obtains the files from Solar System Scope's texture collection [SolarSystemScopeTextures](@cite). AstrodynamicsResources.jl uses the authoritative Solar System Scope download URLs directly and stores the unchanged source files as immutable Julia artifacts.

The body maps are the 2k products (normally 2048×1024 equirectangular images). The Saturn ring alpha map is a special non-2:1 PNG and should not be treated as a body map.

```julia
using AstrodynamicsResources

earth_day = only(resource_paths(:texture_earth_day))
earth_clouds = only(resource_paths(:texture_earth_clouds))
mars = only(resource_paths(:texture_mars))
saturn_ring = only(resource_paths(:texture_saturn_ring))
```

The complete texture bundle contains the Sun; Mercury; Venus surface and atmosphere; Earth day, night and cloud maps; Moon; Mars; Jupiter; Saturn and ring alpha; Uranus; Neptune; four dwarf-planet artistic textures; and two star-sphere textures:

```julia
textures = resource_paths(:planet_textures)
```

The upstream `_fictional` marker is deliberately retained for Ceres, Haumea, Makemake and Eris so artistic impressions cannot be mistaken for measured surface imagery. The Earth normal and specular TIFF products are not included because they are auxiliary rendering maps rather than appearance textures.

Solar System Scope publishes this set under CC BY 4.0; the catalogue records the attribution requirement and source page [SolarSystemScopeTextures](@cite). Immutable texture assets are routed to `resources-textures`.
