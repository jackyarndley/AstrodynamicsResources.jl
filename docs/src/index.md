# AstrodynamicsResources.jl

AstrodynamicsResources.jl is a lazy path provider for astrodynamics data. It
does not interpret the files or alter global SPICE state.

Immutable resources are public, verified Julia artifacts. Rolling resources
use `Scratch.jl`, conditional requests, configurable TTLs, atomic replacement,
and stale-cache fallback. Catalogue inspection is always offline.

The hand-maintained catalogue is deliberately small: every immutable resource
requires only a name and authoritative URL. Hashes, archive identity, size, and
Julia artifact bindings live in generated files. Release archives use names
such as `de440s.tar.gz` and contain the unchanged upstream file at
`data/de440s.bsp`.

DE440s is the recommended compact planetary default. Full DE440 and the newer
DE442/DE442s pair remain separate resources. DE431 and DE441 are excluded.
Planetary-satellite entries describe natural moons, not artificial satellites
or spacecraft.

GOCO06s and GGM05C provide original ICGEM `.gfc` spherical-harmonic
coefficients. This package returns their paths but does not evaluate them.
