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
separate for applications needing its longer coverage. Older DE430, DE432s,
DE435, and DE438 releases are exact, separately addressable resources for
reproducing legacy analyses. The split, multi-gigabyte DE431 and DE441
releases remain excluded by project policy.

Production immutable publication is still pending. The package does not claim
that these resources are materializable until release assets and hashes exist.
