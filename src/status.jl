function _artifact_status(spec::ResourceSpec)
    if !spec.available
        return ResourceStatus(false, :artifact, nothing, nothing, nothing, nothing,
                              nothing, nothing, nothing, "not cached yet")
    end
    hash = _artifact_hash(spec)
    hash === nothing && return ResourceStatus(
        false, :artifact, nothing, nothing, nothing, nothing, nothing, nothing,
        nothing, "artifact is not bound",
    )
    installed = Artifacts.artifact_exists(hash)
    root = installed ? Artifacts.artifact_path(hash) : nothing
    path = if root === nothing
        nothing
    else
        primary = findfirst(file -> file.primary, spec.files)
        joinpath(root, spec.files[something(primary, 1)].path)
    end
    return ResourceStatus(installed && isfile(path), :artifact, path, nothing,
                          nothing, nothing, nothing, nothing,
                          installed && isfile(path) ? filesize(path) : nothing,
                          installed && !isfile(path) ? "expected file is missing" : nothing)
end

function _scratch_status(spec::ResourceSpec)
    root = _scratch_root(spec)
    metadata = _read_metadata(root)
    path = _cache_file(spec, root)
    available = isfile(path)
    fresh = available ? _is_fresh(spec, metadata, path) : false
    checked = _parse_datetime(get(metadata, "last_checked", nothing))
    updated = _parse_datetime(get(metadata, "retrieved_at", nothing))
    sha = haskey(metadata, "sha256") ? String(metadata["sha256"]) : nothing
    size = available ? Int64(filesize(path)) : nothing
    error = haskey(metadata, "last_error") ? String(metadata["last_error"]) : nothing
    return ResourceStatus(available, :scratch, available ? path : nothing, fresh,
                          available ? !fresh : false, checked, updated, sha, size, error)
end

"""
    resource_status(id::Symbol) -> ResourceStatus

Inspect local availability and freshness without network access.
"""
function resource_status(id::Symbol)
    spec = resource(id)
    return spec.backend isa ArtifactBackend ? _artifact_status(spec) : _scratch_status(spec)
end
