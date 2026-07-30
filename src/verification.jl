"""
    verify_resource(id::Symbol; materialize=false, kwargs...) -> Bool

Verify expected files and cached checksums. By default this is local-only;
`materialize=true` explicitly permits obtaining a missing resource.
"""
function verify_resource(id::Symbol; materialize::Bool=false, kwargs...)
    _ensure_catalog()
    if haskey(_BUNDLES, id)
        return all(member -> verify_resource(member; materialize, kwargs...),
                   _bundle_resource_ids(id))
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
        root = _scratch_root(spec)
        metadata = _read_metadata(root)
        expected = get(metadata, "sha256", nothing)
        expected === nothing && return false
        return lowercase(String(expected)) == _file_sha256(status.path)
    end
    hash = _artifact_hash(spec)
    hash === nothing && return false
    Pkg.Artifacts.verify_artifact(hash) || return false
    return all(isfile, _paths_from_root(spec, Artifacts.artifact_path(hash)))
end
