include("releases.jl")

const _PACKAGE_ROOT = normpath(joinpath(@__DIR__, ".."))
const _CATALOG_DIR = joinpath(_PACKAGE_ROOT, "catalog")
const _RESOURCES = Dict{Symbol, ResourceSpec}()
const _ALIASES = Dict{Symbol, Symbol}()
const _BUNDLES = Dict{Symbol, ResourceBundle}()
const _CATALOG_LOADED = Ref(false)
const _LICENSES = Dict{Symbol, Dict{String, String}}()
const _DEFAULT_TTL_SECONDS = 21_600

_catalog_dir_path() = get(ENV, "ASTRODYNAMICS_RESOURCES_CATALOG", _CATALOG_DIR)
_symbols(values) = Symbol.(String.(values))

function _resource_file_path(url::AbstractString)
    path = first(split(first(split(String(url), '?'; limit = 2)), '#'; limit = 2))
    return basename(path)
end

function _source_file_spec(raw::AbstractDict)
    file = Dict{String, Any}(raw)
    url = get(file, "url", nothing)
    url === nothing && throw(ArgumentError("resource file is missing url"))
    filename = String(get(file, "filename", _resource_file_path(url)))
    (isempty(filename) || basename(filename) != filename) &&
        throw(ArgumentError("resource has unsafe filename $filename"))
    spec = Dict{String, Any}("url" => String(url), "filename" => filename)
    haskey(file, "sha256") && (spec["sha256"] = String(file["sha256"]))
    haskey(file, "size_bytes") && (spec["size_bytes"] = Int(file["size_bytes"]))
    return spec
end

function _source_file_specs(entry::Dict{String, Any})
    name = String(entry["name"])
    url = get(entry, "url", nothing)
    files = get(entry, "files", nothing)
    if url !== nothing
        files === nothing ||
            throw(ArgumentError("resource $name must not declare both url and files"))
        raw = Dict{String, Any}("url" => String(url))
        haskey(entry, "filename") && (raw["filename"] = entry["filename"])
        haskey(entry, "sha256") && (raw["sha256"] = entry["sha256"])
        haskey(entry, "size_bytes") && (raw["size_bytes"] = entry["size_bytes"])
        return [_source_file_spec(raw)]
    end
    files === nothing && throw(ArgumentError("resource $name must declare url or files"))
    isempty(files) && throw(ArgumentError("resource $name declares an empty files list"))
    haskey(entry, "filename") &&
        throw(ArgumentError("resource $name must use per-file filename fields with files"))
    specs = [_source_file_spec(raw) for raw in files]
    length(unique(fs["filename"] for fs in specs)) == length(specs) ||
        throw(ArgumentError("resource $name declares duplicate filenames"))
    return specs
end

function _host(url::AbstractString)
    rest = replace(String(url), r"^https://" => "")
    return lowercase(first(split(rest, '/'; limit = 2)))
end

function _provider(url::AbstractString)
    host = _host(url)
    occursin("naif.jpl.nasa.gov", host) && return :naif
    (occursin("cdsarc", host) || occursin("vizier", host)) && return :cds
    occursin("iers.org", host) && return :iers
    occursin("celestrak.org", host) && return :celestrak
    occursin("swpc.noaa.gov", host) && return :noaa_swpc
    occursin("sidc.be", host) && return :silso
    occursin("solarsystemscope.com", host) && return :solarsystemscope
    occursin("icgem", host) && return :icgem
    occursin("gfz", host) && return :gfz
    return Symbol(replace(first(split(host, '.')), '-' => '_'))
end

function _format(filename::AbstractString)
    extension = lowercase(splitext(String(filename))[2])
    return get(
        Dict(
            ".bsp" => "SPICE SPK",
            ".bpc" => "SPICE binary PCK",
            ".tpc" => "SPICE text PCK",
            ".tls" => "SPICE leap-seconds kernel",
            ".tf" => "SPICE frame kernel",
            ".ker" => "SPICE text kernel",
            ".bds" => "SPICE DSK",
            ".gfc" => "ICGEM spherical-harmonic coefficients",
            ".tab" => "text table",
            ".jpg" => "JPEG image",
            ".jpeg" => "JPEG image",
            ".png" => "PNG image",
            ".json" => "JSON",
            ".csv" => "CSV",
            ".txt" => "text",
        ), extension, isempty(extension) ? "data" : uppercase(extension[2:end])
    )
end

function _category(name::AbstractString, filename::AbstractString, live::Bool)
    id = lowercase(String(name))
    extension = lowercase(splitext(String(filename))[2])
    if live
        (
            startswith(id, "iers_") || occursin("eop", id) ||
                occursin("earth_high_precision", id)
        ) && return :earth_orientation
        occursin("leapseconds", id) && return :constants
        return :space_weather
    end
    extension == ".dat" && return :star_catalogue
    extension == ".gfc" && return :gravity
    extension == ".bds" && return :geometry
    extension in (".jpg", ".jpeg", ".png") && return :texture
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
    category in (:gravity, :lunar_gravity) && return :gravity_coefficients
    category == :star_catalogue && return :catalogue
    category == :earth_orientation && return :eop
    category == :space_weather && return :space_weather
    category == :texture && return :texture
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
    (
        startswith(id, "de") || occursin("earth", id) || startswith(id, "iers") ||
            startswith(id, "ggm") || startswith(id, "goco")
    ) && return "Earth"
    return nothing
end

_title(name::AbstractString) = replace(String(name), '_' => ' ')

function _license_fields(entry::Dict{String, Any}, provider::Symbol)
    defaults = get(_LICENSES, provider, nothing)
    fields = Dict{String, Any}()
    for (key, default_key) in (("license", "terms"), ("license_url", "url"))
        value = get(entry, key, defaults === nothing ? nothing : get(defaults, default_key, nothing))
        value === nothing || (fields[key] = String(value))
    end
    return fields
end

function _resource_metadata(
        entry::Dict{String, Any}, name::String, filename::String,
        category::Symbol, source_url::String, metadata_url
    )
    format = category in (:gravity, :lunar_gravity) ?
        "spherical-harmonic coefficients" :
        (category == :star_catalogue ? "CDS fixed-width catalogue" : _format(filename))
    metadata = Dict{String, Any}(
        "source_url" => source_url,
        "source_filename" => filename,
        "format" => format,
    )
    body = get(entry, "body", _body(name))
    body === nothing || (metadata["body"] = body)
    metadata_url === nothing || (metadata["metadata_url"] = String(metadata_url))
    for key in ("description", "citation")
        haskey(entry, key) && (metadata[key] = entry[key])
    end
    return metadata
end

function _live_metadata(entry::Dict{String, Any}, filename::String)
    metadata = Dict{String, Any}(
        "minimum_size_bytes" => Int(get(entry, "minimum_size", 1)),
        "allow_stale" => true,
        "conditional_requests" => true,
        "update_strategy" => "conditional_http",
    )
    endswith(lowercase(filename), ".json") &&
        (metadata["expected_content_type"] = "application/json")
    return metadata
end

function _catalog_source_paths(catalog_dir::String)
    primary = joinpath(catalog_dir, "Resources.toml")
    isfile(primary) || throw(ArgumentError("catalogue is missing $primary"))
    excluded = Set(("Resources.toml", "ResourceLock.toml", "bundles.toml"))
    extras = sort!(
        filter(
            path -> endswith(lowercase(path), ".toml") && !(basename(path) in excluded),
            readdir(catalog_dir; join = true),
        )
    )
    return [primary; extras]
end

function _artifact_complete(
        entry::Dict{String, Any}, source_specs::Vector{Dict{String, Any}}, metadata_url
    )
    haskey(entry, "artifact_sha256") || return false
    haskey(entry, "git_tree_sha1") || return false
    all(haskey(spec, "sha256") for spec in source_specs) || return false
    metadata_url === nothing || haskey(entry, "metadata_sha256") || return false
    return true
end

function _merge_immutable_metadata!(
        metadata::Dict{String, Any}, entry::Dict{String, Any},
        source_specs::Vector{Dict{String, Any}}, metadata_url, name::String, category::Symbol
    )
    if length(source_specs) == 1
        source = only(source_specs)
        haskey(source, "sha256") && (metadata["source_sha256"] = source["sha256"])
        if haskey(source, "size_bytes")
            metadata["source_size_bytes"] = source["size_bytes"]
            metadata["size_bytes"] = source["size_bytes"]
        end
    else
        sources = [copy(spec) for spec in source_specs]
        metadata["source_files"] = sources
        metadata["files"] = sources
    end
    for key in ("artifact_sha256", "artifact_size_bytes", "git_tree_sha1", "metadata_sha256")
        haskey(entry, key) && (metadata[key] = entry[key])
    end
    haskey(metadata, "artifact_sha256") &&
        (metadata["archive_sha256"] = metadata["artifact_sha256"])
    haskey(metadata, "artifact_size_bytes") &&
        (metadata["archive_size_bytes"] = metadata["artifact_size_bytes"])
    metadata["asset"] = "$name.tar.gz"
    base = rstrip(
        get(
            ENV, "ASTRODYNAMICS_RESOURCES_RELEASE_BASE",
            "https://github.com/$(_RESOURCE_REPOSITORY)/releases/download",
        ), '/'
    )
    metadata["download_url"] = "$base/$(_release_tag(category))/$name.tar.gz"
    return metadata
end

function _parse_resource(entry::Dict{String, Any}, aliases::Vector{Symbol})
    name = String(entry["name"])
    source_specs = _source_file_specs(entry)
    url = String(source_specs[1]["url"])
    live = Bool(get(entry, "live", false))
    haskey(entry, "files") && live &&
        throw(ArgumentError("resource $name cannot combine files with live = true"))
    filename = String(source_specs[1]["filename"])
    category = Symbol(get(entry, "category", String(_category(name, filename, live))))
    provider = Symbol(get(entry, "provider", String(_provider(url))))
    files = ResourceFile[
        ResourceFile(
            live ? spec["filename"] : joinpath("data", spec["filename"]),
            _role(category, spec["filename"]), i == 1
        ) for (i, spec) in enumerate(source_specs)
    ]
    metadata_url = get(entry, "metadata_url", nothing)
    if metadata_url !== nothing
        push!(
            files,
            ResourceFile(joinpath("metadata", _resource_file_path(metadata_url)), :metadata, false),
        )
    end

    backend = if live
        urls = [url; String.(get(entry, "mirrors", String[]))]
        ScratchBackend(name, urls, Second(Int(get(entry, "ttl", _DEFAULT_TTL_SECONDS))))
    else
        ArtifactBackend(name)
    end
    metadata = _resource_metadata(entry, name, filename, category, url, metadata_url)
    if live
        merge!(metadata, _live_metadata(entry, filename))
    else
        _merge_immutable_metadata!(metadata, entry, source_specs, metadata_url, name, category)
    end
    merge!(metadata, _license_fields(entry, provider))

    title = String(get(entry, "title", _title(name)))
    description = String(get(entry, "description", "Resource from $(_host(url))."))
    available = live || _artifact_complete(entry, source_specs, metadata_url)
    return ResourceSpec(
        Symbol(name), aliases, title, description, category,
        provider, live ? "rolling" : "pinned", backend,
        files, metadata, available
    )
end

function _load_catalog!()
    _CATALOG_LOADED[] && return nothing
    empty!(_RESOURCES)
    empty!(_ALIASES)
    empty!(_BUNDLES)
    empty!(_LICENSES)
    catalog_dir = _catalog_dir_path()
    catalogues = TOML.parsefile.(_catalog_source_paths(catalog_dir))

    for parsed in catalogues
        for (provider, defaults) in get(parsed, "licenses", Dict{String, Any}())
            key = Symbol(provider)
            value = Dict{String, String}(String(k) => String(v) for (k, v) in defaults)
            if haskey(_LICENSES, key) && _LICENSES[key] != value
                throw(ArgumentError("conflicting license defaults for provider $provider"))
            end
            _LICENSES[key] = value
        end
    end

    alias_table = Dict{String, Any}()
    for parsed in catalogues
        for (alias, target) in get(parsed, "aliases", Dict{String, Any}())
            if haskey(alias_table, alias) && alias_table[alias] != target
                throw(ArgumentError("conflicting alias declaration for $alias"))
            end
            alias_table[String(alias)] = String(target)
        end
    end
    aliases_by_target = Dict{String, Vector{Symbol}}()
    for (alias, target) in alias_table
        push!(get!(aliases_by_target, String(target), Symbol[]), Symbol(alias))
    end

    for parsed in catalogues
        for raw in get(parsed, "resource", Any[])
            entry = Dict{String, Any}(raw)
            name = String(entry["name"])
            haskey(_RESOURCES, Symbol(name)) &&
                throw(ArgumentError("duplicate resource name $name"))
            _RESOURCES[Symbol(name)] =
                _parse_resource(entry, get(aliases_by_target, name, Symbol[]))
        end
    end

    for (alias, target) in alias_table
        _ALIASES[Symbol(alias)] = Symbol(target)
    end
    bundle_path = joinpath(catalog_dir, "bundles.toml")
    if isfile(bundle_path)
        for (name, members) in get(TOML.parsefile(bundle_path), "bundle", Dict())
            id = Symbol(name)
            _BUNDLES[id] = ResourceBundle(
                id, _symbols(members), _title(name), "Ordered resource bundle.",
                Dict{String, Any}("ordered" => true)
            )
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
_valid_sha256(value) = occursin(r"^[0-9a-f]{64}$", lowercase(String(value)))
_valid_tree_hash(value) = occursin(r"^[0-9a-f]{40}$", lowercase(String(value)))

function _validate_artifact_metadata(spec::ResourceSpec)
    spec.backend isa ArtifactBackend || return nothing
    has_artifact = haskey(spec.metadata, "artifact_sha256") ||
        haskey(spec.metadata, "git_tree_sha1")
    has_artifact || return nothing
    spec.available ||
        throw(ArgumentError("resource $(spec.id) has incomplete inline artifact metadata"))
    _valid_sha256(spec.metadata["artifact_sha256"]) ||
        throw(ArgumentError("resource $(spec.id) has invalid artifact_sha256"))
    _valid_tree_hash(spec.metadata["git_tree_sha1"]) ||
        throw(ArgumentError("resource $(spec.id) has invalid git_tree_sha1"))
    if haskey(spec.metadata, "source_files")
        for source in spec.metadata["source_files"]
            _valid_sha256(get(source, "sha256", "")) ||
                throw(ArgumentError("resource $(spec.id) has invalid source file sha256"))
        end
    else
        _valid_sha256(get(spec.metadata, "source_sha256", "")) ||
            throw(ArgumentError("resource $(spec.id) has invalid source_sha256"))
    end
    if haskey(spec.metadata, "metadata_url")
        _valid_sha256(get(spec.metadata, "metadata_sha256", "")) ||
            throw(ArgumentError("resource $(spec.id) has invalid metadata_sha256"))
    end
    return nothing
end

"""
    validate_catalog()

Validate catalogue declarations, inline immutable hashes, aliases, bundles, and
licenses without accessing the network.
"""
function validate_catalog()
    seen_urls = Dict{String, Symbol}()
    for spec in values(_RESOURCES)
        name = String(spec.id)
        occursin(r"^[a-z][a-z0-9_]*$", name) ||
            throw(ArgumentError("resource name $name is not a safe Julia identifier"))
        license = get(spec.metadata, "license", nothing)
        license === nothing && throw(
            ArgumentError(
                "resource $name has no license terms; add an explicit license field or a " *
                    "[licenses] default for provider $(spec.provider)",
            )
        )
        license_url = get(spec.metadata, "license_url", nothing)
        license_url !== nothing && !startswith(String(license_url), "https://") &&
            throw(ArgumentError("resource $name must use an HTTPS license_url"))

        sources = haskey(spec.metadata, "source_files") ?
            spec.metadata["source_files"] :
            [Dict{String, Any}(
                "url" => spec.metadata["source_url"],
                "filename" => spec.metadata["source_filename"],
            )]
        for source in sources
            url = String(source["url"])
            startswith(url, "https://") ||
                throw(ArgumentError("resource $name must use HTTPS source URLs"))
            haskey(seen_urls, url) &&
                throw(ArgumentError("resources $(seen_urls[url]) and $name share URL $url"))
            seen_urls[url] = spec.id
            filename = String(source["filename"])
            (isempty(filename) || basename(filename) != filename) &&
                throw(ArgumentError("resource $name has unsafe filename $filename"))
        end
        count(file -> file.primary, spec.files) == 1 ||
            throw(ArgumentError("resource $name must have exactly one primary file"))
        _validate_artifact_metadata(spec)
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
        return push!(visited, id)
    end
    foreach(visit, keys(_BUNDLES))
    return true
end
