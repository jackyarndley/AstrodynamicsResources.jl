"""
    resource(id::Symbol) -> ResourceSpec

Return catalogue metadata for a resource. This operation never accesses the network or
materializes data.
"""
function resource(id::Symbol)
    _ensure_catalog()
    canonical = _canonical_id(id)
    haskey(_RESOURCES, canonical) ||
        throw(KeyError("unknown resource $id; use list_resources() or find_resources()"))
    return _RESOURCES[canonical]
end

function _matches(value, requested)
    requested === nothing && return true
    value === nothing && return false
    return lowercase(String(value)) == lowercase(String(requested))
end

"""
    list_resources(; category=nothing, provider=nothing, system=nothing,
                     body=nothing, backend=nothing, format=nothing,
                     available=nothing)

List resources using catalogue-only filters. No network access is performed.
"""
function list_resources(;
        category = nothing, provider = nothing, system = nothing,
        body = nothing, backend = nothing, format = nothing,
        available = nothing
    )
    _ensure_catalog()
    specs = filter(collect(values(_RESOURCES))) do spec
        _matches(spec.category, category) &&
            _matches(spec.provider, provider) &&
            _matches(get(spec.metadata, "system", nothing), system) &&
            _matches(get(spec.metadata, "body", nothing), body) &&
            _matches(backend_symbol(spec.backend), backend) &&
            _matches(get(spec.metadata, "format", nothing), format) &&
            (available === nothing || spec.available == Bool(available))
    end
    sort!(specs; by = spec -> String(spec.id))
    return specs
end

function _search_text(spec::ResourceSpec)
    fields = Any[
        spec.id, spec.aliases, spec.title, spec.description, spec.category,
        spec.provider, spec.version,
    ]
    append!(fields, values(spec.metadata))
    return lowercase(join(string.(fields), " "))
end

"""
    find_resources(query; filters...) -> Vector{ResourceSpec}

Perform normalized local text search over resource metadata.
"""
function find_resources(
        query::AbstractString; category = nothing, provider = nothing,
        system = nothing, body = nothing, backend = nothing
    )
    terms = split(lowercase(strip(query)))
    specs = list_resources(; category, provider, system, body, backend)
    return filter(specs) do spec
        haystack = _search_text(spec)
        all(term -> occursin(term, haystack), terms)
    end
end

function Base.show(io::IO, spec::ResourceSpec)
    status = resource_status(spec.id)
    println(io, "Resource $(spec.id): $(spec.title)")
    println(io, "  category: $(spec.category)    provider: $(spec.provider)")
    println(io, "  version: $(spec.version)    backend: $(backend_symbol(spec.backend))")
    println(io, "  format: $(get(spec.metadata, "format", "unknown"))    size: $(get(spec.metadata, "size_bytes", "unknown"))")
    coverage = filter(
        !isempty, String[
            string(get(spec.metadata, "coverage_start", "")),
            string(get(spec.metadata, "coverage_end", "")),
        ]
    )
    !isempty(coverage) && println(io, "  coverage: ", join(coverage, " — "))
    body = get(spec.metadata, "body", get(spec.metadata, "system", nothing))
    body !== nothing && println(io, "  body/system: ", body)
    println(io, "  local: ", status.available ? "available" : "not materialized")
    source = get(spec.metadata, "source_filename", nothing)
    source !== nothing && println(io, "  source file: ", source)
    source_files = get(spec.metadata, "source_files", nothing)
    if source_files !== nothing && length(source_files) > 1
        println(io, "  source files: $(length(source_files)) parts")
    end
    citation = get(spec.metadata, "citation", nothing)
    citation !== nothing && println(io, "  citation: ", citation)
    license = get(spec.metadata, "license", nothing)
    license !== nothing && println(io, "  license: ", license)
    license_url = get(spec.metadata, "license_url", nothing)
    if license_url !== nothing
        println(io, "  license URL: ", license_url)
    end
    return nothing
end

"""
    bundle(id::Symbol) -> ResourceBundle

Inspect an ordered logical bundle without materializing its members.
"""
function bundle(id::Symbol)
    _ensure_catalog()
    haskey(_BUNDLES, id) || throw(KeyError("unknown bundle $id"))
    return _BUNDLES[id]
end

function _bundle_resource_ids(id::Symbol, result::Vector{Symbol} = Symbol[])
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
    return print(io, "  ordered members: ", join(value.members, ", "))
end

"""
    resource_paths(id::Symbol; kwargs...) -> Vector{String}

Materialize a resource, alias, or ordered bundle and return the local path of
every file (data files first, then metadata), in declaration order. This is
the single path accessor: use `only(resource_paths(id))` when the resource has
exactly one primary file.
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
    return spec.backend isa ArtifactBackend ? _artifact_paths(spec) : _scratch_paths(spec; kwargs...)
end
