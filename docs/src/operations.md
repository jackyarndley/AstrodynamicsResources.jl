# Offline operation, freshness, and provenance

Set `ASTRODYNAMICS_RESOURCES_OFFLINE=true` to prohibit network access. Installed
artifacts still work. Cached live products are returned when `stale_ok=true`;
otherwise a missing or stale cache produces an actionable error.

```julia
status = resource_status(:iers_finals2000a)
refresh!(:iers_finals2000a)
verify_resource(:iers_finals2000a)
clear_resource!(:iers_finals2000a)
```

Live metadata records the selected source URL, retrieval and check times, ETag,
Last-Modified value where supplied, content type, SHA-256, byte size, and
freshness deadline. TTLs can be overridden per resource, for example
`ASTRODYNAMICS_RESOURCES_TTL_IERS_FINALS2000A=1800`.

If refresh fails, the prior valid file remains untouched. Downloads use a
temporary `.part` file and only replace the destination after validation and
hashing.

Immutable artifact archives contain the original upstream bytes under `data/`,
associated comments under `metadata/`, and `provenance.toml`. The packager does
not normalize line endings or rewrite kernels. Mirrors are additional immutable
download entries; mutable branch URLs and overwritten assets are forbidden.

Packaging downloads use a persistent content-addressed source cache controlled
by `ASTRODYNAMICS_RESOURCES_SOURCE_CACHE` (default `build/source-cache`).
Interrupted transfers resume from `.part` files, provider checksums are checked
where available, and a verified source is reused between package releases.
GitHub Actions also caches each reviewed source build. Published archives are
added to the durable `resources-v1` release and an existing asset name is reused
only when its remote and local SHA-256 digests match.

Dataset citations are available in `resource(id).metadata["citation"]`. Cite
each scientific dataset separately from this package.
