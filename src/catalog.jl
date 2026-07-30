const _PACKAGE_ROOT = normpath(joinpath(@__DIR__, ".."))
const _CATALOG_DIR = joinpath(_PACKAGE_ROOT, "catalog")
const _ARTIFACTS_TOML = joinpath(_PACKAGE_ROOT, "Artifacts.toml")
const _RESOURCES = Dict{Symbol,ResourceSpec}()
const _ALIASES = Dict{Symbol,Symbol}()
const _BUNDLES = Dict{Symbol,ResourceBundle}()
const _CATALOG_LOADED = Ref(false)
const _SUPPORTED_CATEGORIES = Set([
    :ephemeris, :satellite_ephemeris, :constants, :orientation,
    :gravity, :geometry, :earth_orientation, :space_weather, :fixture,
])

_symbols(values) = Symbol.(String.(values))
_catalog_dir_path() = get(ENV, "ASTRODYNAMICS_RESOURCES_CATALOG", _CATALOG_DIR)

function _parse_files(entry::Dict{String,Any})
    values = get(entry, "files", Any[])
    files = ResourceFile[]
    for value in values
        push!(files, ResourceFile(
            String(value["path"]),
            Symbol(get(value, "role", "data")),
            Bool(get(value, "primary", false)),
        ))
    end
    isempty(files) && throw(ArgumentError("resource $(entry["id"]) has no files"))
    return files
end

function _entry_metadata(entry::Dict{String,Any})
    structural = Set([
        "id", "aliases", "title", "description", "category", "provider",
        "version", "backend", "artifact_name", "key", "urls", "ttl_seconds",
        "files", "available",
    ])
    return Dict{String,Any}(key => value for (key, value) in entry if !(key in structural))
end

function _parse_resource(entry::Dict{String,Any})
    backend_name = get(entry, "backend", nothing)
    backend_name == "artifact" && !haskey(entry, "artifact_name") &&
        throw(ArgumentError("artifact resource $(entry["id"]) has no artifact_name"))
    backend = if backend_name == "artifact"
        ArtifactBackend(String(entry["artifact_name"]))
    elseif backend_name == "scratch"
        urls = String.(get(entry, "urls", String[]))
        isempty(urls) && throw(ArgumentError("scratch resource $(entry["id"]) has no URLs"))
        ScratchBackend(String(get(entry, "key", entry["id"])), urls,
                       Second(Int(get(entry, "ttl_seconds", 3600))))
    else
        throw(ArgumentError("resource $(entry["id"]) has invalid backend $(repr(backend_name))"))
    end
    return ResourceSpec(
        Symbol(entry["id"]),
        _symbols(get(entry, "aliases", String[])),
        String(entry["title"]),
        String(entry["description"]),
        Symbol(entry["category"]),
        Symbol(entry["provider"]),
        String(entry["version"]),
        backend,
        _parse_files(entry),
        _entry_metadata(entry),
        Bool(get(entry, "available", true)),
    )
end

function _load_catalog!()
    _CATALOG_LOADED[] && return nothing
    empty!(_RESOURCES)
    empty!(_ALIASES)
    empty!(_BUNDLES)
    catalog_dir = _catalog_dir_path()
    isdir(catalog_dir) || throw(ArgumentError("catalog directory is missing: $catalog_dir"))
    files = sort(filter(path -> endswith(path, ".toml") && basename(path) != "bundles.toml",
                        readdir(catalog_dir; join=true)))
    for file in files
        parsed = TOML.parsefile(file)
        defaults = Dict{String,Any}(get(parsed, "defaults", Dict{String,Any}()))
        for raw_entry in get(parsed, "resource", Any[])
            entry = merge(defaults, Dict{String,Any}(raw_entry))
            spec = _parse_resource(entry)
            haskey(_RESOURCES, spec.id) &&
                throw(ArgumentError("duplicate resource ID $(spec.id)"))
            _RESOURCES[spec.id] = spec
        end
    end
    for spec in values(_RESOURCES), alias in spec.aliases
        haskey(_RESOURCES, alias) &&
            throw(ArgumentError("alias $alias collides with a resource ID"))
        haskey(_ALIASES, alias) &&
            throw(ArgumentError("duplicate resource alias $alias"))
        _ALIASES[alias] = spec.id
    end
    bundle_file = joinpath(catalog_dir, "bundles.toml")
    if isfile(bundle_file)
        for entry in get(TOML.parsefile(bundle_file), "bundle", Any[])
            id = Symbol(entry["id"])
            haskey(_BUNDLES, id) && throw(ArgumentError("duplicate bundle ID $id"))
            metadata = Dict{String,Any}(key => value for (key, value) in entry
                                        if !(key in ("id", "members", "title", "description")))
            _BUNDLES[id] = ResourceBundle(
                id, _symbols(entry["members"]), String(entry["title"]),
                String(entry["description"]), metadata,
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

function _artifact_table()
    path = _artifacts_toml_path()
    isfile(path) || return Dict{String,Any}()
    return TOML.parsefile(path)
end

_artifacts_toml_path() = get(ENV, "ASTRODYNAMICS_RESOURCES_ARTIFACTS_TOML", _ARTIFACTS_TOML)

"""
    validate_catalog()

Validate all loaded resource and bundle definitions without network access.
Returns `true` on success and throws `ArgumentError` with an actionable message
on the first invalid definition.
"""
function validate_catalog()
    artifact_table = _artifact_table()
    seen_sources = Dict{String,Symbol}()
    for spec in values(_RESOURCES)
        spec.category in _SUPPORTED_CATEGORIES ||
            throw(ArgumentError("resource $(spec.id) has unsupported category $(spec.category)"))
        count(file -> file.primary, spec.files) <= 1 ||
            throw(ArgumentError("resource $(spec.id) has multiple primary files"))
        length(unique(file.path for file in spec.files)) == length(spec.files) ||
            throw(ArgumentError("resource $(spec.id) repeats a file path"))
        for file in spec.files
            isabspath(file.path) &&
                throw(ArgumentError("resource $(spec.id) contains an absolute file path"))
            any(part -> part == "..", splitpath(file.path)) &&
                throw(ArgumentError("resource $(spec.id) contains a parent path"))
        end
        if spec.backend isa ArtifactBackend
            name = spec.backend.artifact_name
            required = ("source_url", "source_filename", "format", "citation",
                        "license", "redistribution", "retrieved_at")
            missing = filter(key -> !haskey(spec.metadata, key), required)
            isempty(missing) || throw(ArgumentError(
                "artifact resource $(spec.id) lacks metadata: $(join(missing, ", "))"
            ))
            if haskey(spec.metadata, "source_sha256")
                occursin(r"^[0-9a-f]{64}$", String(spec.metadata["source_sha256"])) ||
                    throw(ArgumentError("artifact resource $(spec.id) has an invalid source SHA-256"))
            end
            if spec.available
                haskey(artifact_table, name) ||
                    throw(ArgumentError("available artifact $(spec.id) is absent from Artifacts.toml"))
                binding = artifact_table[name]
                binding isa AbstractDict ||
                    throw(ArgumentError("platform-specific artifact $name requires explicit validation support"))
                Bool(get(binding, "lazy", false)) ||
                    throw(ArgumentError("artifact $name must be marked lazy"))
                tree = String(get(binding, "git-tree-sha1", ""))
                occursin(r"^[0-9a-f]{40}$", tree) ||
                    throw(ArgumentError("artifact $name has an invalid git-tree-sha1"))
                downloads = get(binding, "download", Any[])
                isempty(downloads) &&
                    throw(ArgumentError("artifact $name has no stable download"))
                for download in downloads
                    startswith(String(get(download, "url", "")), "https://") ||
                        throw(ArgumentError("artifact $name has a non-HTTPS download"))
                    occursin(r"^[0-9a-f]{64}$", String(get(download, "sha256", ""))) ||
                        throw(ArgumentError("artifact $name has an invalid archive SHA-256"))
                end
            end
        else
            required = ("source_filename", "format", "citation", "license",
                        "redistribution", "minimum_size_bytes",
                        "update_strategy", "allow_stale", "conditional_requests")
            missing = filter(key -> !haskey(spec.metadata, key), required)
            isempty(missing) || throw(ArgumentError(
                "scratch resource $(spec.id) lacks metadata: $(join(missing, ", "))"
            ))
            for url in (spec.backend::ScratchBackend).urls
                startswith(url, "https://") ||
                    throw(ArgumentError("scratch resource $(spec.id) has a non-HTTPS URL"))
            end
            key = (spec.backend::ScratchBackend).key
            (isempty(key) || key in (".", "..") || basename(key) != key) &&
                throw(ArgumentError("scratch resource $(spec.id) has an unsafe cache key"))
        end
        source = get(spec.metadata, "source_url", nothing)
        if source !== nothing
            startswith(source, "https://") ||
                throw(ArgumentError("resource $(spec.id) has a non-HTTPS source URL"))
            if haskey(seen_sources, source) &&
               !Bool(get(spec.metadata, "allow_duplicate_source", false))
                throw(ArgumentError("resources $(seen_sources[source]) and $(spec.id) share source URL $source"))
            end
            seen_sources[source] = spec.id
        end
    end
    for b in values(_BUNDLES)
        (haskey(_RESOURCES, b.id) || haskey(_ALIASES, b.id)) &&
            throw(ArgumentError("bundle $(b.id) collides with a resource ID or alias"))
        length(unique(b.members)) == length(b.members) ||
            throw(ArgumentError("bundle $(b.id) contains duplicate members"))
        for member in b.members
            canonical = _canonical_id(member)
            (haskey(_RESOURCES, canonical) || haskey(_BUNDLES, member)) ||
                throw(ArgumentError("bundle $(b.id) refers to missing member $member"))
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
