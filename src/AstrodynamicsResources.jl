module AstrodynamicsResources

using Artifacts
using Dates
using Downloads
using LazyArtifacts
import Pkg
using SHA
using Scratch
using TOML

export AbstractResourceBackend, ArtifactBackend, ScratchBackend
export ResourceFile, ResourceSpec, ResourceBundle, ResourceStatus
export resource, resource_info, list_resources, find_resources, bundle
export resource_paths
export resource_status, refresh!, clear_resource!, verify_resource
export validate_catalog

"""Backend shared by immutable artifacts and mutable scratch resources."""
abstract type AbstractResourceBackend end

"""Immutable lazy-artifact backend."""
struct ArtifactBackend <: AbstractResourceBackend
    artifact_name::String
end

"""Mutable URL-backed scratch cache with a refresh TTL."""
struct ScratchBackend <: AbstractResourceBackend
    key::String
    urls::Vector{String}
    ttl::Second
end

"""A relative path and role within a resource."""
struct ResourceFile
    path::String
    role::Symbol
    primary::Bool
end

"""Catalogue metadata for one independently materializable resource."""
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
    metadata::Dict{String,Any}
    available::Bool
end

"""Ordered logical collection of resource IDs."""
struct ResourceBundle
    id::Symbol
    members::Vector{Symbol}
    title::String
    description::String
    metadata::Dict{String,Any}
end

"""Local availability, freshness, and checksum diagnostics."""
struct ResourceStatus
    available::Bool
    backend::Symbol
    path::Union{Nothing,String}
    fresh::Union{Nothing,Bool}
    stale::Union{Nothing,Bool}
    last_checked::Union{Nothing,DateTime}
    last_updated::Union{Nothing,DateTime}
    sha256::Union{Nothing,String}
    size_bytes::Union{Nothing,Int64}
    error::Union{Nothing,String}
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
    print(io, ")")
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
