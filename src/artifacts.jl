function _unpublished_error(spec::ResourceSpec)
    source = get(spec.metadata, "source_url", "the authoritative upstream")
    return ErrorException(
        "resource $(spec.id) is catalogued but its immutable artifact has not " *
        "been published and verified. Expected source: $source. Build and publish " *
        "it with scripts/build_artifact.jl, then add its verified hashes to Artifacts.toml."
    )
end

function _artifact_hash(spec::ResourceSpec)
    spec.backend isa ArtifactBackend || return nothing
    toml = _artifacts_toml_path()
    isfile(toml) || return nothing
    return Artifacts.artifact_hash(spec.backend.artifact_name, toml)
end

function _artifact_root(spec::ResourceSpec)
    spec.available || throw(_unpublished_error(spec))
    hash = _artifact_hash(spec)
    hash === nothing && throw(ErrorException(
        "artifact $(spec.backend.artifact_name) for resource $(spec.id) is not bound in $_ARTIFACTS_TOML"
    ))
    if !Artifacts.artifact_exists(hash)
        _offline() && throw(ErrorException(
            "resource $(spec.id) is missing in offline mode (backend=artifact). " *
            "Materialize it once while online with materialize(:$(spec.id))."
        ))
        Pkg.Artifacts.ensure_artifact_installed(
            spec.backend.artifact_name, _artifacts_toml_path())
    end
    return Artifacts.artifact_path(hash)
end

function _paths_from_root(spec::ResourceSpec, root::String)
    paths = String[]
    for file in spec.files
        path = normpath(joinpath(root, file.path))
        isfile(path) || throw(ErrorException(
            "resource $(spec.id) is incomplete: expected file $(file.path) is missing from $root"
        ))
        push!(paths, path)
    end
    return paths
end

_artifact_paths(spec::ResourceSpec) = _paths_from_root(spec, _artifact_root(spec))
