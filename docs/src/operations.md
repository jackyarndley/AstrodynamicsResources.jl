# Offline operation, caching, and integrity

Set `ASTRODYNAMICS_RESOURCES_OFFLINE=true` to prohibit network access. Installed
artifacts continue to work. Cached live products may be returned with
`stale_ok=true`.

```julia
status = resource_status(:iers_finals2000a)
refresh!(:iers_finals2000a)
verify_resource(:iers_finals2000a)
clear_resource!(:iers_finals2000a)
```

Live cache metadata records retrieval/check times, ETag, Last-Modified,
SHA-256, size, and freshness. Downloads use temporary `.part` files and atomic
replacement; a failed update leaves the previous valid file intact. Override a
TTL with `ASTRODYNAMICS_RESOURCES_TTL_<NAME>`.

Immutable identity is generated in `catalog/ResourceLock.toml` and bound lazily
in `Artifacts.toml`. Those files record both the archive SHA-256 and Julia's
`git-tree-sha1`; release assets deliberately have no display label so GitHub
shows their readable filenames. Archives contain unchanged source bytes,
optional companion metadata, and separate provenance.

The Actions source cache key is stable per resource name, so unchanged upstream
downloads are reused across commits and package releases.
