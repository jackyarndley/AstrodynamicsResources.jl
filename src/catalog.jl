const _PACKAGE_ROOT = normpath(joinpath(@__DIR__, ".."))
const _CATALOG_DIR = joinpath(_PACKAGE_ROOT, "catalog")
const _ARTIFACTS_TOML = joinpath(_PACKAGE_ROOT, "Artifacts.toml")
const _RESOURCES = Dict{Symbol,ResourceSpec}()
const _ALIASES = Dict{Symbol,Symbol}()
const _BUNDLES = Dict{Symbol,ResourceBundle}()
const _CATALOG_LOADED = Ref(false)

_catalog_dir_path() = get(ENV, "ASTRODYNAMICS_RESOURCES_CATALOG", _CATALOG_DIR)
_artifacts_toml_path() = get(
    ENV, "ASTRODYNAMICS_RESOURCES_ARTIFACTS_TOML", _ARTIFACTS_TOML)
_symbols(values) = Symbol.(String.(values))

function _resource_file_path(url::AbstractString)
    path = first(split(first(split(String(url), '?'; limit=2)), '#'; limit=2))
    return basename(path)
end

function _host(url::AbstractString)
    rest = replace(String(url), r"^https://" => "")
    return lowercase(first(split(rest, '/'; limit=2)))
end

function _provider(url::AbstractString)
    host = _host(url)
    occursin("naif.jpl.nasa.gov", host) && return :naif
    occursin("iers.org", host) && return :iers
    occursin("celestrak.org", host) && return :celestrak
    occursin("swpc.noaa.gov", host) && return :noaa_swpc
    occursin("sidc.be", host) && return :silso
    occursin("icgem", host) && return :icgem
    occursin("gfz", host) && return :gfz
    return Symbol(replace(first(split(host, '.')), '-' => '_'))
end

function _format(filename::AbstractString)
    extension = lowercase(splitext(String(filename))[2])
    return get(Dict(
        ".bsp" => "SPICE SPK",
        ".bpc" => "SPICE binary PCK",
        ".tpc" => "SPICE text PCK",
        ".tls" => "SPICE leap-seconds kernel",
        ".tf" => "SPICE frame kernel",
        ".ker" => "SPICE text kernel",
        ".bds" => "SPICE DSK",
        ".gfc" => "ICGEM spherical-harmonic coefficients",
        ".json" => "JSON",
        ".csv" => "CSV",
        ".txt" => "text",
    ), extension, isempty(extension) ? "data" : uppercase(extension[2:end]))
end

function _category(name::AbstractString, filename::AbstractString, live::Bool)
    id = lowercase(String(name))
    extension = lowercase(splitext(String(filename))[2])
    if live
        (startswith(id, "iers_") || occursin("eop", id) ||
         occursin("earth_high_precision", id)) && return :earth_orientation
        occursin("leapseconds", id) && return :constants
        return :space_weather
    end
    extension == ".gfc" && return :gravity
    extension == ".bds" && return :geometry
    extension == ".bsp" && return occursin(r"^de\d", id) ? :ephemeris : :satellite_ephemeris
    extension == ".bpc" && return startswith(id, "moon_") ? :orientation : :earth_orientation
    extension == ".tf" && startswith(id, "moon_") && return :orientation
    extension == ".tf" && occursin("nameid", id) && return :satellite_ephemeris
    extension in (".tpc", ".tls", ".tf", ".ker") && return :constants
    return :data
end

function _role(category::Symbol, filename::AbstractString)
    extension = lowercase(splitext(String(filename))[2])
    extension == ".bsp" && return :spk
    extension == ".bpc" && return :binary_pck
    extension == ".tpc" && return :text_pck
    extension == ".tls" && return :lsk
    extension == ".tf" && return :frame_kernel
    extension == ".bds" && return :dsk
    extension == ".gfc" && return :gravity_coefficients
    category == :earth_orientation && return :eop
    category == :space_weather && return :space_weather
    return :data
end

function _body(name::AbstractString)
    id = lowercase(String(name))
    occursin("moon", id) && return "Moon"
    occursin("phobos", id) && return "Phobos"
    occursin("eros", id) && return "Eros"
    occursin("itokawa", id) && return "Itokawa"
    occursin("vesta", id) && return "Vesta"
    startswith(id, "mar") && return "Mars"
    startswith(id, "jup") && return "Jupiter"
    startswith(id, "sat") && return "Saturn"
    startswith(id, "ura") && return "Uranus"
    startswith(id, "nep") && return "Neptune"
    startswith(id, "plu") && return "Pluto"
    (startswith(id, "de") || occursin("earth", id) || startswith(id, "iers") ||
     startswith(id, "ggm") || startswith(id, "goco")) && return "Earth"
    return nothing
end

_title(name::AbstractString) = replace(String(name), '_' => ' ')

function _lock_table(catalog_dir::String)
    path = joinpath(catalog_dir, "ResourceLock.toml")
    isfile(path) || return Dict{String,Any}()
    parsed = TOML.parsefile(path)
    Int(get(parsed, "version", 0)) == 1 ||
        throw(ArgumentError("ResourceLock.toml has an unsupported version"))
    return Dict{String,Any}(get(parsed, "resources", Dict{String,Any}()))
end

function _parse_resource(entry::Dict{String,Any}, aliases::Vector{Symbol},
                         lock::Union{Nothing,Dict{String,Any}},
                         artifact_table::Dict{String,Any})
    name = String(entry["name"])
    url = String(entry["url"])
    live = Bool(get(entry, "live", false))
    filename = String(get(entry, "filename", _resource_file_path(url)))
    category = Symbol(get(entry, "category", String(_category(name, filename, live))))
    provider = Symbol(get(entry, "provider", String(_provider(url))))
    files = ResourceFile[
        ResourceFile(live ? filename : joinpath("data", filename),
                     _role(category, filename), true),
    ]
    metadata_url = get(entry, "metadata_url", nothing)
    if metadata_url !== nothing
        push!(files, ResourceFile(joinpath("metadata", _resource_file_path(metadata_url)),
                                 :metadata, false))
    end

    backend = if live
        urls = [url; String.(get(entry, "mirrors", String[]))]
        ScratchBackend(name, urls, Second(Int(get(entry, "ttl", 21_600))))
    else
        ArtifactBackend(name)
    end
    metadata = Dict{String,Any}(
        "source_url" => url,
        "source_filename" => filename,
        "format" => _format(filename),
    )
    body = get(entry, "body", _body(name))
    body === nothing || (metadata["body"] = body)
    metadata_url === nothing || (metadata["metadata_url"] = String(metadata_url))
    for key in ("description", "citation", "license")
        haskey(entry, key) && (metadata[key] = entry[key])
    end
    if live
        metadata["minimum_size_bytes"] = Int(get(entry, "minimum_size", 1))
        metadata["allow_stale"] = true
        metadata["conditional_requests"] = true
        metadata["update_strategy"] = "conditional_http"
        endswith(lowercase(filename), ".json") &&
            (metadata["expected_content_type"] = "application/json")
    elseif lock !== nothing
        merge!(metadata, lock)
        haskey(lock, "source_size_bytes") &&
            (metadata["size_bytes"] = lock["source_size_bytes"])
    end

    title = String(get(entry, "title", _title(name)))
    description = String(get(entry, "description", "Resource from $(_host(url))."))
    available = live || (lock !== nothing && haskey(artifact_table, name))
    return ResourceSpec(Symbol(name), aliases, title, description, category,
                        provider, live ? "rolling" : "pinned", backend,
                        files, metadata, available)
end

function _load_catalog!()
    _CATALOG_LOADED[] && return nothing
    empty!(_RESOURCES)
    empty!(_ALIASES)
    empty!(_BUNDLES)
    catalog_dir = _catalog_dir_path()
    resources_path = joinpath(catalog_dir, "Resources.toml")
    isfile(resources_path) ||
        throw(ArgumentError("catalogue is missing $resources_path"))
    parsed = TOML.parsefile(resources_path)
    alias_table = Dict{String,Any}(get(parsed, "aliases", Dict{String,Any}()))
    aliases_by_target = Dict{String,Vector{Symbol}}()
    for (alias, target) in alias_table
        push!(get!(aliases_by_target, String(target), Symbol[]), Symbol(alias))
    end
    locks = _lock_table(catalog_dir)
    artifact_table = _artifact_table()
    for raw in get(parsed, "resource", Any[])
        entry = Dict{String,Any}(raw)
        name = String(entry["name"])
        haskey(_RESOURCES, Symbol(name)) &&
            throw(ArgumentError("duplicate resource name $name"))
        lock = haskey(locks, name) ? Dict{String,Any}(locks[name]) : nothing
        _RESOURCES[Symbol(name)] = _parse_resource(
            entry, get(aliases_by_target, name, Symbol[]), lock, artifact_table)
    end
    declared = Set(String(id) for id in keys(_RESOURCES))
    unknown_locks = setdiff(Set(keys(locks)), declared)
    isempty(unknown_locks) ||
        throw(ArgumentError("ResourceLock.toml contains unknown resources: " *
                            join(sort!(collect(unknown_locks)), ", ")))
    unknown_artifacts = setdiff(Set(keys(artifact_table)), declared)
    isempty(unknown_artifacts) ||
        throw(ArgumentError("Artifacts.toml contains unknown resources: " *
                            join(sort!(collect(unknown_artifacts)), ", ")))
    for (alias, target) in alias_table
        _ALIASES[Symbol(alias)] = Symbol(target)
    end
    bundle_path = joinpath(catalog_dir, "bundles.toml")
    if isfile(bundle_path)
        for (name, members) in get(TOML.parsefile(bundle_path), "bundle", Dict())
            id = Symbol(name)
            _BUNDLES[id] = ResourceBundle(
                id, _symbols(members), _title(name), "Ordered resource bundle.",
                Dict{String,Any}("ordered" => true))
        end
    end
    validate_catalog()
    _CATALOG_LOADED[] = true
    return nothing
end

function _ensure_catalog()
    _CATALOG_LOADED[] || _load_catalog!()
    return nothing
end

_canonical_id(id::Symbol) = get(_ALIASES, id, id)

function _artifact_table()
    path = _artifacts_toml_path()
    isfile(path) || return Dict{String,Any}()
    return TOML.parsefile(path)
end

"""
    validate_catalog()

Validate the small hand-edited catalogue, generated lock, artifacts, aliases,
and bundles without accessing the network.
"""
function validate_catalog()
    artifact_table = _artifact_table()
    seen_urls = Dict{String,Symbol}()
    for spec in values(_RESOURCES)
        name = String(spec.id)
        occursin(r"^[a-z][a-z0-9_]*$", name) ||
            throw(ArgumentError("resource name $name is not a safe Julia identifier"))
        url = String(spec.metadata["source_url"])
        startswith(url, "https://") ||
            throw(ArgumentError("resource $name must use an HTTPS URL"))
        haskey(seen_urls, url) &&
            throw(ArgumentError("resources $(seen_urls[url]) and $name share URL $url"))
        seen_urls[url] = spec.id
        filename = String(spec.metadata["source_filename"])
        (isempty(filename) || basename(filename) != filename) &&
            throw(ArgumentError("resource $name has unsafe filename $filename"))
        count(file -> file.primary, spec.files) == 1 ||
            throw(ArgumentError("resource $name must have exactly one primary file"))
        if spec.backend isa ArtifactBackend &&
           haskey(spec.metadata, "git_tree_sha1")
            for (key, pattern) in (
                    "source_sha256" => r"^[0-9a-f]{64}$",
                    "archive_sha256" => r"^[0-9a-f]{64}$",
                    "git_tree_sha1" => r"^[0-9a-f]{40}$")
                occursin(pattern, String(get(spec.metadata, key, ""))) ||
                    throw(ArgumentError("resource $name has invalid $key"))
            end
            String(get(spec.metadata, "source_filename", "")) == filename ||
                throw(ArgumentError("resource $name lock filename does not match its URL"))
            haskey(artifact_table, name) ||
                throw(ArgumentError("locked resource $name is absent from Artifacts.toml"))
            binding = artifact_table[name]
            Bool(get(binding, "lazy", false)) ||
                throw(ArgumentError("artifact $name must be lazy"))
            String(get(binding, "git-tree-sha1", "")) == spec.metadata["git_tree_sha1"] ||
                throw(ArgumentError("artifact $name tree hash differs from ResourceLock.toml"))
            downloads = get(binding, "download", Any[])
            length(downloads) == 1 ||
                throw(ArgumentError("artifact $name must have one immutable download"))
            String(downloads[1]["sha256"]) == spec.metadata["archive_sha256"] ||
                throw(ArgumentError("artifact $name archive hash differs from ResourceLock.toml"))
        elseif spec.backend isa ArtifactBackend && haskey(artifact_table, name)
            throw(ArgumentError("artifact $name is bound but missing from ResourceLock.toml"))
        end
    end
    for (alias, target) in _ALIASES
        haskey(_RESOURCES, alias) &&
            throw(ArgumentError("alias $alias collides with a resource name"))
        haskey(_RESOURCES, target) ||
            throw(ArgumentError("alias $alias refers to missing resource $target"))
    end
    for value in values(_BUNDLES)
        length(unique(value.members)) == length(value.members) ||
            throw(ArgumentError("bundle $(value.id) contains duplicate members"))
        for member in value.members
            canonical = _canonical_id(member)
            (haskey(_RESOURCES, canonical) || haskey(_BUNDLES, member)) ||
                throw(ArgumentError("bundle $(value.id) refers to missing member $member"))
        end
    end
    visiting = Set{Symbol}()
    visited = Set{Symbol}()
    function visit(id::Symbol)
        id in visiting && throw(ArgumentError("bundle cycle involving $id"))
        id in visited && return
        push!(visiting, id)
        for member in _BUNDLES[id].members
            haskey(_BUNDLES, member) && visit(member)
        end
        delete!(visiting, id)
        push!(visited, id)
    end
    foreach(visit, keys(_BUNDLES))
    return true
end
