"""
    bundle(id::Symbol) -> ResourceBundle

Inspect an ordered logical bundle without materializing its members.
"""
function bundle(id::Symbol)
    _ensure_catalog()
    haskey(_BUNDLES, id) ||
        throw(KeyError("unknown bundle $id"))
    return _BUNDLES[id]
end

function _bundle_resource_ids(id::Symbol, result::Vector{Symbol}=Symbol[])
    for member in bundle(id).members
        if haskey(_BUNDLES, member)
            _bundle_resource_ids(member, result)
        else
            push!(result, member)
        end
    end
    return result
end

function Base.show(io::IO, value::ResourceBundle)
    println(io, "ResourceBundle $(value.id): $(value.title)")
    println(io, "  ", value.description)
    print(io, "  ordered members: ", join(value.members, ", "))
end

"""
    resource_paths(id::Symbol; kwargs...) -> Vector{String}

Materialize a resource or ordered bundle and return local paths. The result is
always a vector.
"""
function resource_paths(id::Symbol; kwargs...)
    _ensure_catalog()
    if haskey(_BUNDLES, id)
        paths = String[]
        for member in _bundle_resource_ids(id)
            append!(paths, resource_paths(member; kwargs...))
        end
        return paths
    end
    spec = resource(id)
    if spec.backend isa ArtifactBackend
        return _artifact_paths(spec)
    end
    return _scratch_paths(spec; kwargs...)
end

"""
    resource_path(id::Symbol; kwargs...) -> String

Materialize a single-primary-file resource and return that file's local path.
Throws for bundles and multipart resources.
"""
function resource_path(id::Symbol; kwargs...)
    _ensure_catalog()
    haskey(_BUNDLES, id) && throw(ArgumentError(
        "$id is a bundle; use resource_paths(:$id) to preserve its documented order"
    ))
    spec = resource(id)
    primary = findall(file -> file.primary, spec.files)
    length(spec.files) == 1 || length(primary) == 1 || throw(ArgumentError(
        "resource $id has multiple files and no unique primary; use resource_paths(:$id)"
    ))
    paths = resource_paths(id; kwargs...)
    if length(spec.files) == 1
        return only(paths)
    end
    return paths[only(primary)]
end

"""
    materialize(id::Symbol; kwargs...)
    materialize(ids::AbstractVector{Symbol}; kwargs...)

Explicitly install or update requested resources and return vectors of local
paths. A vector input returns one path vector per requested ID.
"""
materialize(id::Symbol; kwargs...) = resource_paths(id; kwargs...)

function materialize(ids::AbstractVector{Symbol}; kwargs...)
    return [resource_paths(id; kwargs...) for id in ids]
end
