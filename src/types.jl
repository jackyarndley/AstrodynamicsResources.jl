"""
Supertype for immutable artifact and mutable scratch resource backends.
"""
abstract type AbstractResourceBackend end

"""
    ArtifactBackend(artifact_name)

Backend for immutable content stored as a lazy Julia artifact.
"""
struct ArtifactBackend <: AbstractResourceBackend
    artifact_name::String
end

"""
    ScratchBackend(key, urls, ttl)

Backend for a mutable upstream product cached in package scratch space.
"""
struct ScratchBackend <: AbstractResourceBackend
    key::String
    urls::Vector{String}
    ttl::Second
end

"""
    ResourceFile(path, role, primary)

A relative file path within a resource, its semantic role, and whether it is
the resource's primary file.
"""
struct ResourceFile
    path::String
    role::Symbol
    primary::Bool
end

"""
Catalogue record describing one independently materializable resource.
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
    metadata::Dict{String,Any}
    available::Bool
end

"""
Ordered logical collection of resource IDs. Bundles never duplicate file data.
"""
struct ResourceBundle
    id::Symbol
    members::Vector{Symbol}
    title::String
    description::String
    metadata::Dict{String,Any}
end

"""
Local availability, freshness, checksum, and cache diagnostics for a resource.
"""
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
