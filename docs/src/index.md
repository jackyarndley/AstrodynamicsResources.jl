# AstrodynamicsResources.jl

AstrodynamicsResources.jl provides a unified local-path interface to
astrodynamics data. It manages files; it does not interpret their scientific
contents. Downstream packages may consume returned paths without becoming core
dependencies here.

Every resource is lazy. Immutable resources are Julia artifacts and mutable
operational products are explicit scratch-cache downloads. Importing, listing,
searching, displaying, and inspecting bundles are network-free.

## Why two backends?

An immutable kernel or coefficient model must keep a permanent identity.
Artifacts bind an archive SHA-256 to a Julia `git-tree-sha1` and can respect
normal depot configuration and artifact overrides. A rolling EOP or
space-weather file deliberately changes at the same URL, so it is cached with
retrieval metadata, a checksum, and a freshness deadline instead.

DE440s is the compact recommended ephemeris for most users. Full DE440 is
separate for applications needing its longer coverage. DE430, DE432s, DE435,
DE438, DE442, and DE442s are exact, separately addressable resources. The
split, multi-gigabyte DE431 and DE441 releases remain excluded by project
policy. Planetary-satellite ephemerides here describe natural moons, including
the explicit multipart Uranus `ura184` product. Artificial Earth-satellite and
spacecraft kernels are not catalogued.

Production immutable binding is still pending. Verified archives are collected
under the private repository's `resources-v1` release, but private GitHub asset
URLs are not usable by Julia's standard unauthenticated artifact downloader.
The package therefore does not claim that these resources are materializable
until compatible stable hosting and all hashes exist.
All currently catalogued immutable resources are unmodified kernels obtained
from NAIF's generic-kernel tree. NAIF explicitly permits redistribution of
NAIF-distributed kernels while they remain unmodified; catalogue metadata links
the governing policy and preserves the required provenance.

Gravity coefficient models remain candidate metadata rather than active
resources. The package does not yet provide a materializable spherical-harmonic
coefficient file.
