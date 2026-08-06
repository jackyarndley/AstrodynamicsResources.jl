module AstrodynamicsResources

import Pkg

using Artifacts, Dates, Downloads, LazyArtifacts, Scratch, SHA, TOML

export AbstractResourceBackend, ArtifactBackend, ScratchBackend
export ResourceFile, ResourceSpec, ResourceBundle, ResourceStatus
export resource, list_resources, find_resources, bundle
export resource_paths
export resource_status, refresh!, clear_resource!, verify_resource
export validate_catalog

"""Backend shared by immutable artifacts and mutable scratch resources."""
abstract type AbstractResourceBackend end

"""
    ArtifactBackend(artifact_name)

Immutable lazy-artifact backend.

# Fields
- `artifact_name::String`: name of the Julia artifact binding.
"""
struct ArtifactBackend <: AbstractResourceBackend
    artifact_name::String
end

"""
    ScratchBackend(key, urls, ttl)

Mutable URL-backed scratch cache with a refresh TTL.

# Fields
- `key::String`: scratch-cache key.
- `urls::Vector{String}`: upstream URLs tried in order.
- `ttl::Second`: cache freshness lifetime.
"""
struct ScratchBackend <: AbstractResourceBackend
    key::String
    urls::Vector{String}
    ttl::Second
end

"""
    ResourceFile(path, role, primary)

A relative path and role within a resource.

# Fields
- `path::String`: path relative to the resource root.
- `role::Symbol`: file role (for example `:spk` or `:metadata`).
- `primary::Bool`: whether this is the primary file.
"""
struct ResourceFile
    path::String
    role::Symbol
    primary::Bool
end

"""
    ResourceSpec(id, aliases, title, description, category, provider, version,
                 backend, files, metadata, available)

Catalogue metadata for one independently materializable resource.

# Fields
- `id::Symbol`: canonical resource identifier.
- `aliases::Vector{Symbol}`: accepted alias identifiers.
- `title::String`: human-readable title.
- `description::String`: short description.
- `category::Symbol`: resource family.
- `provider::Symbol`: data provider.
- `version::String`: pinned version or `"rolling"`.
- `backend::AbstractResourceBackend`: artifact or scratch backend.
- `files::Vector{ResourceFile}`: files included in the resource.
- `metadata::Dict{String, Any}`: inferred and locked metadata.
- `available::Bool`: whether the resource is locked or live.
"""
struct ResourceSpec
    id::Symbol
    aliases::Vector{Symbol}
    title::String
    description::String
    category::Symbol
    provider::Symbol
    version::String
    backend::AbstractResourceBackend
    files::Vector{ResourceFile}
    metadata::Dict{String, Any}
    available::Bool
end

"""
    ResourceBundle(id, members, title, description, metadata)

Ordered logical collection of resource IDs.

# Fields
- `id::Symbol`: bundle identifier.
- `members::Vector{Symbol}`: member resource or bundle IDs in order.
- `title::String`: human-readable title.
- `description::String`: short description.
- `metadata::Dict{String, Any}`: bundle metadata.
"""
struct ResourceBundle
    id::Symbol
    members::Vector{Symbol}
    title::String
    description::String
    metadata::Dict{String, Any}
end

"""
    ResourceStatus(available, backend, path, fresh, stale, last_checked,
                   last_updated, sha256, size_bytes, error)

Local availability, freshness, and checksum diagnostics.

# Fields
- `available::Bool`: whether the resource is present locally.
- `backend::Symbol`: `:artifact` or `:scratch`.
- `path::Union{Nothing, String}`: primary local path when available.
- `fresh::Union{Nothing, Bool}`: freshness for scratch resources.
- `stale::Union{Nothing, Bool}`: staleness for scratch resources.
- `last_checked::Union{Nothing, DateTime}`: last validation time.
- `last_updated::Union{Nothing, DateTime}`: last download time.
- `sha256::Union{Nothing, String}`: cached content checksum.
- `size_bytes::Union{Nothing, Int64}`: cached file size.
- `error::Union{Nothing, String}`: last recorded error message.
"""
struct ResourceStatus
    available::Bool
    backend::Symbol
    path::Union{Nothing, String}
    fresh::Union{Nothing, Bool}
    stale::Union{Nothing, Bool}
    last_checked::Union{Nothing, DateTime}
    last_updated::Union{Nothing, DateTime}
    sha256::Union{Nothing, String}
    size_bytes::Union{Nothing, Int64}
    error::Union{Nothing, String}
end

backend_symbol(::ArtifactBackend) = :artifact
backend_symbol(::ScratchBackend) = :scratch

function Base.show(io::IO, status::ResourceStatus)
    print(io, "ResourceStatus(", status.backend, ", ")
    print(io, status.available ? "available" : "missing")
    status.fresh === true && print(io, ", fresh")
    status.stale === true && print(io, ", stale")
    status.path !== nothing && print(io, ", ", repr(status.path))
    status.error !== nothing && print(io, ", error=", repr(status.error))
    return print(io, ")")
end

const _TRUE_VALUES = Set(("1", "true", "yes", "on"))
const _FALSE_VALUES = Set(("0", "false", "no", "off"))

function _env_bool(name::String, default::Bool)
    raw = lowercase(strip(get(ENV, name, string(default))))
    raw in _TRUE_VALUES && return true
    raw in _FALSE_VALUES && return false
    throw(ArgumentError("$name must be one of true/false, 1/0, yes/no, or on/off"))
end

_offline() = _env_bool("ASTRODYNAMICS_RESOURCES_OFFLINE", false)
_allow_stale() = _env_bool("ASTRODYNAMICS_RESOURCES_ALLOW_STALE", true)

function _timeout()
    value = tryparse(Float64, get(ENV, "ASTRODYNAMICS_RESOURCES_TIMEOUT", "60"))
    return value === nothing || value <= 0 ? 60.0 : value
end

function _max_downloads()
    value = tryparse(Int, get(ENV, "ASTRODYNAMICS_RESOURCES_MAX_DOWNLOADS", "4"))
    return value === nothing || value < 1 ? 4 : value
end

function _ttl_seconds(spec::ResourceSpec)
    name = "ASTRODYNAMICS_RESOURCES_TTL_" * uppercase(replace(String(spec.id), '-' => '_'))
    value = tryparse(Int, get(ENV, name, ""))
    return value === nothing || value < 0 ? Dates.value((spec.backend::ScratchBackend).ttl) : value
end

function _live_urls(spec::ResourceSpec)
    urls = copy((spec.backend::ScratchBackend).urls)
    mirror = strip(get(ENV, "ASTRODYNAMICS_RESOURCES_MIRROR", ""))
    if !isempty(mirror)
        filename = get(spec.metadata, "source_filename", first(spec.files).path)
        pushfirst!(urls, rstrip(mirror, '/') * "/" * filename)
    end
    unique!(urls)
    return urls
end

include("catalog.jl")
include("queries.jl")
include("artifacts.jl")
include("scratch.jl")

function __init__()
    _load_catalog!()
    return nothing
end

end
