#!/usr/bin/env julia

using AstrodynamicsResources
using TOML
import Pkg

include(joinpath(@__DIR__, "lib", "artifact_archive.jl"))
include(joinpath(@__DIR__, "lib", "source_cache.jl"))
include(joinpath(@__DIR__, "lib", "catalog_editor.jl"))
using .ArtifactArchiveSupport
using .SourceCache
using .CatalogEditor

const _ROOT = normpath(joinpath(@__DIR__, ".."))

function usage(io::IO = stdout)
    return print(
        io, """
        usage: catalog.jl COMMAND [ARGS...]

        Commands:
          add NAME URL [--live] [--category CATEGORY] [--license TERMS] [--license-url URL]
              Append a minimal resource declaration to catalog/Resources.toml.
          validate
              Validate declarations, inline hashes, aliases, bundles, and licenses.
          uncached
              Print and (in CI) emit immutable resources without complete artifact hashes.
          build NAME [OUTPUT_ROOT]
              Download and verify upstream data, then build a deterministic archive/report.
          adopt NAME ARCHIVE EXTRACTED_ROOT [OUTPUT_ROOT]
              Verify an already-published archive and create its report without rebuilding it.
          update REPORT_OR_DIRECTORY
              Write successful report hashes back into the owning resource declarations.
        """
    )
end

json(values) = "[" * join(('"' * value * '"' for value in values), ",") * "]"

const _ADD_FLAGS = Dict(
    "--live" => ("live", true),
    "--category" => ("category", false),
    "--license" => ("license", false),
    "--license-url" => ("license_url", false),
)

function cmd_add(args)
    2 <= length(args) <= 2 + 2 * length(_ADD_FLAGS) ||
        error("usage: catalog.jl add NAME URL [--live] [--category ...] [--license ...] [--license-url ...]")
    name, url = args[1], args[2]
    occursin(r"^[a-z][a-z0-9_]*$", name) || error("invalid resource name $name")
    startswith(url, "https://") || error("resource URL must use HTTPS")
    fields = Pair{String, String}[]
    i = 3
    while i <= length(args)
        flag = args[i]
        haskey(_ADD_FLAGS, flag) || error("unknown flag $flag")
        key, boolean = _ADD_FLAGS[flag]
        if boolean
            push!(fields, key => "true")
            i += 1
        else
            i + 1 <= length(args) || error("missing value for $flag")
            push!(fields, key => args[i + 1])
            i += 2
        end
    end
    path = joinpath(_ROOT, "catalog", "Resources.toml")
    text = read(path, String)
    occursin("name = " * repr(name), text) && error("resource $name already exists")
    open(path, "a") do io
        println(io, "\n[[resource]]")
        println(io, "name = ", repr(name))
        println(io, "url = ", repr(url))
        for (key, value) in fields
            key == "live" ? println(io, "live = true") : println(io, key, " = ", repr(value))
        end
    end
    return println("added $name; commit the declaration and the cache workflow will fill its hashes")
end

function cmd_validate()
    validate_catalog()
    immutable = list_resources(backend = :artifact)
    live = list_resources(backend = :scratch)
    return println(
        "catalogue valid: $(length(immutable) + length(live)) resources " *
        "($(length(immutable)) immutable, $(length(live)) live, " *
        "$(count(spec -> spec.available, immutable)) cached)"
    )
end

function cmd_uncached()
    names = sort!(
        String[String(spec.id) for spec in list_resources(backend = :artifact) if !spec.available]
    )
    if haskey(ENV, "GITHUB_OUTPUT")
        open(ENV["GITHUB_OUTPUT"], "a") do io
            println(io, "resources=", json(names))
            println(io, "count=", length(names))
        end
    end
    return println(json(names))
end

function _declared_sources(spec::ResourceSpec)
    if haskey(spec.metadata, "source_files")
        return [Dict{String, Any}(file) for file in spec.metadata["source_files"]]
    end
    source = Dict{String, Any}(
        "url" => String(spec.metadata["source_url"]),
        "filename" => String(spec.metadata["source_filename"]),
    )
    haskey(spec.metadata, "source_sha256") &&
        (source["sha256"] = String(spec.metadata["source_sha256"]))
    haskey(spec.metadata, "source_size_bytes") &&
        (source["size_bytes"] = Int(spec.metadata["source_size_bytes"]))
    return [source]
end

function _fetch_sources(spec::ResourceSpec, cache_root::String)
    source_items = Dict{String, Any}[]
    for declared in _declared_sources(spec)
        file_meta = Dict{String, Any}(
            "source_url" => String(declared["url"]),
            "source_filename" => String(declared["filename"]),
        )
        haskey(declared, "sha256") &&
            (file_meta["source_sha256"] = String(declared["sha256"]))
        haskey(declared, "size_bytes") &&
            (file_meta["size_bytes"] = Int(declared["size_bytes"]))
        local_path = fetch_verified_source(
            file_meta; cache_root, require_sha256 = false,
            verify_size = haskey(file_meta, "size_bytes")
        )
        push!(
            source_items,
            Dict{String, Any}(
                "filename" => file_meta["source_filename"],
                "url" => file_meta["source_url"],
                "path" => local_path,
                "sha256" => file_sha256(local_path),
                "size_bytes" => filesize(local_path),
            ),
        )
    end
    return source_items
end

function _fetch_metadata(spec::ResourceSpec, cache_root::String)
    metadata_url = get(spec.metadata, "metadata_url", nothing)
    metadata_url === nothing && return nothing, nothing
    metadata_name = basename(String(metadata_url))
    associated = Dict{String, Any}(
        "source_url" => String(metadata_url),
        "source_filename" => metadata_name,
    )
    haskey(spec.metadata, "metadata_sha256") &&
        (associated["source_sha256"] = String(spec.metadata["metadata_sha256"]))
    path = fetch_verified_source(
        associated; cache_root, require_sha256 = false, verify_size = false
    )
    return path, file_sha256(path)
end

function _write_provenance(
        directory::String, spec::ResourceSpec, source_items::Vector{Dict{String, Any}},
        metadata_sha
    )
    provenance = Dict{String, Any}(
        "name" => String(spec.id),
        "source_url" => source_items[1]["url"],
        "source_filename" => source_items[1]["filename"],
        "packager" => "AstrodynamicsResources.jl",
    )
    if length(source_items) == 1
        provenance["source_sha256"] = source_items[1]["sha256"]
    else
        provenance["files"] = [
            Dict{String, Any}(
                "filename" => item["filename"],
                "url" => item["url"],
                "sha256" => item["sha256"],
                "size_bytes" => item["size_bytes"],
            ) for item in source_items
        ]
    end
    haskey(spec.metadata, "metadata_url") &&
        (provenance["metadata_url"] = spec.metadata["metadata_url"])
    metadata_sha === nothing || (provenance["metadata_sha256"] = metadata_sha)
    for key in ("license", "license_url", "citation")
        haskey(spec.metadata, key) && (provenance[key] = spec.metadata[key])
    end
    open(joinpath(directory, "provenance.toml"), "w") do io
        TOML.print(io, provenance; sorted = true)
    end
    return nothing
end

function _create_tree(
        spec::ResourceSpec, source_items::Vector{Dict{String, Any}},
        metadata_source, metadata_sha
    )
    return Pkg.Artifacts.create_artifact() do directory
        data_dir = joinpath(directory, "data")
        mkpath(data_dir)
        for item in source_items
            cp(item["path"], joinpath(data_dir, item["filename"]); force = false)
        end
        if metadata_source !== nothing
            metadata_dir = joinpath(directory, "metadata")
            mkpath(metadata_dir)
            cp(metadata_source, joinpath(metadata_dir, basename(metadata_source)); force = false)
        end
        _write_provenance(directory, spec, source_items, metadata_sha)
    end
end

function _report(
        spec::ResourceSpec, source_items::Vector{Dict{String, Any}}, archive::String,
        tree, metadata_sha
    )
    report = Dict{String, Any}(
        "name" => String(spec.id),
        "source_url" => source_items[1]["url"],
        "source_filename" => source_items[1]["filename"],
        "asset" => basename(archive),
        "archive_sha256" => file_sha256(archive),
        "archive_size_bytes" => filesize(archive),
        "git_tree_sha1" => string(tree),
    )
    if length(source_items) == 1
        report["source_sha256"] = source_items[1]["sha256"]
        report["source_size_bytes"] = source_items[1]["size_bytes"]
    else
        report["files"] = [
            Dict{String, Any}(
                "filename" => item["filename"],
                "url" => item["url"],
                "sha256" => item["sha256"],
                "size_bytes" => item["size_bytes"],
            ) for item in source_items
        ]
    end
    if haskey(spec.metadata, "metadata_url")
        report["metadata_url"] = spec.metadata["metadata_url"]
        report["metadata_sha256"] = metadata_sha
    end
    return report
end

function _write_report(report::Dict{String, Any}, root::String)
    report_dir = joinpath(root, "reports")
    mkpath(report_dir)
    path = joinpath(report_dir, "$(report["name"]).toml")
    open(path, "w") do io
        TOML.print(io, report; sorted = true)
    end
    return path
end

function cmd_build(args)
    isempty(args) && error("usage: catalog.jl build NAME [OUTPUT_ROOT]")
    root = length(args) > 1 ? abspath(args[2]) : joinpath(_ROOT, "build")
    id = Symbol(first(args))
    spec = resource(id)
    spec.backend isa ArtifactBackend || error("$id is a live resource")
    cache_root = abspath(
        get(ENV, "ASTRODYNAMICS_RESOURCES_SOURCE_CACHE", joinpath(root, "source-cache"))
    )
    source_items = _fetch_sources(spec, cache_root)
    metadata_source, metadata_sha = _fetch_metadata(spec, cache_root)
    tree = _create_tree(spec, source_items, metadata_source, metadata_sha)

    artifact_dir = joinpath(root, "artifacts")
    mkpath(artifact_dir)
    archive = joinpath(artifact_dir, "$(id).tar.gz")
    isfile(archive) && error("refusing to overwrite $archive")
    deterministic_archive_artifact(tree, archive)
    path = _write_report(_report(spec, source_items, archive, tree, metadata_sha), root)
    println("built $(id).tar.gz")
    return path
end

function _adopt_source_items(spec::ResourceSpec, extracted::String)
    items = Dict{String, Any}[]
    for declared in _declared_sources(spec)
        path = joinpath(extracted, "data", declared["filename"])
        isfile(path) || error("published archive is missing data/$(declared["filename"])")
        sha = file_sha256(path)
        haskey(declared, "sha256") && lowercase(String(declared["sha256"])) != sha &&
            error("published source hash differs from declared hash for $(declared["filename"])")
        push!(
            items,
            Dict{String, Any}(
                "filename" => declared["filename"],
                "url" => declared["url"],
                "path" => path,
                "sha256" => sha,
                "size_bytes" => filesize(path),
            ),
        )
    end
    return items
end

function _adopt_tree(extracted::String)
    return Pkg.Artifacts.create_artifact() do directory
        for item in readdir(extracted)
            cp(joinpath(extracted, item), joinpath(directory, item); force = false)
        end
    end
end

function cmd_adopt(args)
    length(args) in (3, 4) ||
        error("usage: catalog.jl adopt NAME ARCHIVE EXTRACTED_ROOT [OUTPUT_ROOT]")
    id = Symbol(args[1])
    archive = abspath(args[2])
    extracted = abspath(args[3])
    root = length(args) == 4 ? abspath(args[4]) : joinpath(_ROOT, "build")
    spec = resource(id)
    spec.backend isa ArtifactBackend || error("$id is a live resource")
    isfile(archive) || error("archive does not exist: $archive")
    isdir(extracted) || error("extracted root does not exist: $extracted")

    source_items = _adopt_source_items(spec, extracted)
    metadata_sha = nothing
    if haskey(spec.metadata, "metadata_url")
        metadata_path = joinpath(
            extracted, "metadata", AstrodynamicsResources._resource_file_path(spec.metadata["metadata_url"])
        )
        isfile(metadata_path) || error("published archive is missing metadata file")
        metadata_sha = file_sha256(metadata_path)
        haskey(spec.metadata, "metadata_sha256") &&
            lowercase(String(spec.metadata["metadata_sha256"])) != metadata_sha &&
            error("published metadata hash differs from declared hash")
    end
    tree = _adopt_tree(extracted)
    report = _report(spec, source_items, archive, tree, metadata_sha)
    path = _write_report(report, root)
    println("adopted $(id).tar.gz")
    return path
end

function report_files(path::String)
    isfile(path) && return [path]
    isdir(path) || error("report path does not exist: $path")
    return sort(filter(file -> endswith(file, ".toml"), readdir(path; join = true)))
end

function cmd_update(args)
    length(args) == 1 || error("usage: catalog.jl update REPORT_OR_DIRECTORY")
    files = report_files(abspath(only(args)))
    isempty(files) && error("no resource reports found")
    reports = [Dict{String, Any}(TOML.parsefile(path)) for path in files]
    changed = update_reports!(_ROOT, reports)
    println("updated $(length(reports)) resource declaration(s) in $(length(changed)) file(s)")
    return changed
end

function main(args = ARGS)
    isempty(args) && (usage(); exit(1))
    args = copy(args)
    command = popfirst!(args)
    command == "add" && return cmd_add(args)
    command == "validate" && isempty(args) && return cmd_validate()
    command == "uncached" && isempty(args) && return cmd_uncached()
    command == "build" && return cmd_build(args)
    command == "adopt" && return cmd_adopt(args)
    command == "update" && return cmd_update(args)
    usage(stderr)
    return exit(1)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
