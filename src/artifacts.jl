function _unpublished_error(spec::ResourceSpec)
    source = get(spec.metadata, "source_url", "the authoritative upstream")
    return ErrorException(
        "resource $(spec.id) is declared but has not been cached yet. Source: $source. " *
            "Merge the declaration to main or run the Cache resources workflow; it will " *
            "publish the archive and add the immutable hashes to the resource declaration."
    )
end

function _artifact_binding(spec::ResourceSpec)
    spec.available || throw(_unpublished_error(spec))
    return Dict{String, Any}(
        spec.backend.artifact_name => Dict{String, Any}(
            "git-tree-sha1" => String(spec.metadata["git_tree_sha1"]),
            "lazy" => true,
            "download" => [
                Dict{String, Any}(
                    "url" => resource_download_url(spec),
                    "sha256" => String(spec.metadata["artifact_sha256"]),
                ),
            ],
        ),
    )
end

function _with_artifact_toml(f::Function, spec::ResourceSpec)
    return mktemp() do path, io
        TOML.print(io, _artifact_binding(spec); sorted = true)
        close(io)
        return f(path)
    end
end

function _artifact_hash(spec::ResourceSpec)
    spec.backend isa ArtifactBackend || return nothing
    spec.available || return nothing
    return _with_artifact_toml(spec) do toml
        Artifacts.artifact_hash(spec.backend.artifact_name, toml)
    end
end

function _artifact_root(spec::ResourceSpec)
    spec.available || throw(_unpublished_error(spec))
    hash = _artifact_hash(spec)
    hash === nothing && throw(ErrorException("resource $(spec.id) has no artifact hash"))
    if !Artifacts.artifact_exists(hash)
        _offline() && throw(
            ErrorException(
                "resource $(spec.id) is missing in offline mode (backend=artifact). " *
                    "Call resource_paths(:$(spec.id)) while online to materialize it."
            )
        )
        _with_artifact_toml(spec) do toml
            Pkg.Artifacts.ensure_artifact_installed(spec.backend.artifact_name, toml)
        end
    end
    return Artifacts.artifact_path(hash)
end

function _paths_from_root(spec::ResourceSpec, root::String)
    paths = String[]
    for file in spec.files
        path = normpath(joinpath(root, file.path))
        isfile(path) || throw(
            ErrorException(
                "resource $(spec.id) is incomplete: expected file $(file.path) is missing from $root"
            )
        )
        push!(paths, path)
    end
    return paths
end

_artifact_paths(spec::ResourceSpec) = _paths_from_root(spec, _artifact_root(spec))

function _artifact_status(spec::ResourceSpec)
    if !spec.available
        return ResourceStatus(
            false, :artifact, nothing, nothing, nothing, nothing,
            nothing, nothing, nothing, "not cached yet",
        )
    end
    hash = _artifact_hash(spec)
    hash === nothing && return ResourceStatus(
        false, :artifact, nothing, nothing, nothing, nothing, nothing, nothing,
        nothing, "artifact has no tree hash",
    )
    installed = Artifacts.artifact_exists(hash)
    root = installed ? Artifacts.artifact_path(hash) : nothing
    path = if root === nothing
        nothing
    else
        primary = findfirst(file -> file.primary, spec.files)
        joinpath(root, spec.files[something(primary, 1)].path)
    end
    present = path !== nothing && isfile(path)
    return ResourceStatus(
        present, :artifact, path, nothing, nothing, nothing,
        nothing, nothing, present ? filesize(path) : nothing,
        installed && !present ? "expected file is missing" : nothing,
    )
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
    return ResourceStatus(
        available, :scratch, available ? path : nothing, fresh,
        available ? !fresh : false, checked, updated, sha, size, error,
    )
end

"""
    resource_status(id::Symbol) -> ResourceStatus

Inspect local availability and freshness without network access.
"""
function resource_status(id::Symbol)
    spec = resource(id)
    return spec.backend isa ArtifactBackend ? _artifact_status(spec) : _scratch_status(spec)
end

"""
    verify_resource(id::Symbol; materialize = false, kwargs...) -> Bool

Verify expected files and cached checksums, optionally materializing first.
"""
function verify_resource(id::Symbol; materialize::Bool = false, kwargs...)
    _ensure_catalog()
    if haskey(_BUNDLES, id)
        return all(
            member -> verify_resource(member; materialize, kwargs...),
            _bundle_resource_ids(id),
        )
    end
    spec = resource(id)
    status = resource_status(id)
    if !status.available
        materialize || return false
        resource_paths(id; kwargs...)
        status = resource_status(id)
    end
    status.path === nothing && return false
    if spec.backend isa ScratchBackend
        metadata = _read_metadata(_scratch_root(spec))
        expected = get(metadata, "sha256", nothing)
        return expected !== nothing && lowercase(String(expected)) == _file_sha256(status.path)
    end
    hash = _artifact_hash(spec)
    hash === nothing && return false
    Pkg.Artifacts.verify_artifact(hash) || return false
    return all(isfile, _paths_from_root(spec, Artifacts.artifact_path(hash)))
end
