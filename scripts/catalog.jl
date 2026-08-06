#!/usr/bin/env julia

using AstrodynamicsResources
using TOML
import Pkg

include(joinpath(@__DIR__, "lib", "artifact_archive.jl"))
include(joinpath(@__DIR__, "lib", "source_cache.jl"))
using .ArtifactArchiveSupport
using .SourceCache

const _ROOT = normpath(joinpath(@__DIR__, ".."))

function usage(io::IO=stdout)
    print(io, """
    usage: catalog.jl COMMAND [ARGS...]

    Commands:
      add NAME URL [--live] [--category CATEGORY] [--license TERMS] [--license-url URL]
          Append a resource declaration to catalog/Resources.toml.
      validate
          Validate the catalogue, lock, artifacts, aliases, bundles, and licenses.
      uncached
          Print and (in CI) emit the names of immutable resources not yet locked.
      scan ASSET_FILE
          Compare locked resources against published release assets; emit uncached names.
      build NAME [OUTPUT_ROOT]
          Download the upstream source, verify it, and build a deterministic archive.
      update-lock [REPORT_OR_DIRECTORY RELEASE_DOWNLOAD_BASE]
          Generate ResourceLock.toml/Artifacts.toml from build reports and sync
          license metadata from the catalogue; with no arguments, only sync licenses.
    """)
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
    fields = Pair{String,String}[]
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
    occursin("name = " * repr(name), text) &&
        error("resource $name already exists")
    open(path, "a") do io
        println(io, "\n[[resource]]")
        println(io, "name = ", repr(name))
        println(io, "url = ", repr(url))
        for (key, value) in fields
            key == "live" ? println(io, "live = true") : println(io, key, " = ", repr(value))
        end
    end
    println("added $name; commit Resources.toml and the cache workflow will do the rest")
end

function cmd_validate()
    validate_catalog()
    immutable = list_resources(backend=:artifact)
    live = list_resources(backend=:scratch)
    println("catalogue valid: $(length(immutable) + length(live)) resources ",
            "($(length(immutable)) immutable, $(length(live)) live, ",
            "$(count(spec -> spec.available, immutable)) cached)")
end

function cmd_uncached()
    names = sort!(String[
        String(spec.id) for spec in list_resources(backend=:artifact) if !spec.available
    ])
    if haskey(ENV, "GITHUB_OUTPUT")
        open(ENV["GITHUB_OUTPUT"], "a") do io
            println(io, "resources=", json(names))
            println(io, "count=", length(names))
        end
    end
    println(json(names))
end

function cmd_scan(path::String)
    published = Set(filter(!isempty, strip.(readlines(path))))
    specs = list_resources(backend=:artifact)
    missing = sort!(String[
        String(spec.id) for spec in specs
        if spec.available && !(String(spec.metadata["asset"]) in published)
    ])
    names = sort!(String[String(spec.id) for spec in specs if !spec.available])
    if haskey(ENV, "GITHUB_OUTPUT")
        open(ENV["GITHUB_OUTPUT"], "a") do io
            println(io, "uncached=", json(names))
            println(io, "uncached_count=", length(names))
        end
    end
    println("uncached: ", join(names, ", "))
    isempty(missing) || error(
        "locked resources missing from the release: " * join(missing, ", "))
end

function cmd_build(args)
    isempty(args) && error("usage: catalog.jl build NAME [OUTPUT_ROOT]")
    root = length(args) > 1 ? abspath(args[2]) : joinpath(_ROOT, "build")
    id = Symbol(first(args))
    spec = resource(id)
    spec.backend isa ArtifactBackend || error("$id is a live resource")
    source_name = String(spec.metadata["source_filename"])
    source_metadata = Dict{String,Any}(
        "source_url" => spec.metadata["source_url"],
        "source_filename" => source_name,
    )
    haskey(spec.metadata, "source_sha256") &&
        (source_metadata["source_sha256"] = spec.metadata["source_sha256"])
    cache_root = abspath(get(
        ENV, "ASTRODYNAMICS_RESOURCES_SOURCE_CACHE",
        joinpath(root, "source-cache")))
    source = fetch_verified_source(
        source_metadata; cache_root, require_sha256=false, verify_size=false)
    source_sha = file_sha256(source)

    metadata_source = nothing
    metadata_sha = nothing
    metadata_url = get(spec.metadata, "metadata_url", nothing)
    if metadata_url !== nothing
        metadata_name = basename(String(metadata_url))
        associated = Dict{String,Any}(
            "source_url" => String(metadata_url),
            "source_filename" => metadata_name,
        )
        haskey(spec.metadata, "metadata_sha256") &&
            (associated["source_sha256"] = spec.metadata["metadata_sha256"])
        metadata_source = fetch_verified_source(
            associated; cache_root, require_sha256=false, verify_size=false)
        metadata_sha = file_sha256(metadata_source)
    end

    tree = Pkg.Artifacts.create_artifact() do directory
        data_dir = joinpath(directory, "data")
        mkpath(data_dir)
        cp(source, joinpath(data_dir, source_name); force=false)
        if metadata_source !== nothing
            metadata_dir = joinpath(directory, "metadata")
            mkpath(metadata_dir)
            cp(metadata_source, joinpath(metadata_dir, basename(metadata_source)); force=false)
        end
        provenance = Dict{String,Any}(
            "name" => String(id),
            "source_url" => spec.metadata["source_url"],
            "source_filename" => source_name,
            "source_sha256" => source_sha,
            "packager" => "AstrodynamicsResources.jl/0.1.0",
        )
        for key in ("metadata_url", "metadata_sha256", "license", "license_url", "citation")
            haskey(spec.metadata, key) && (provenance[key] = spec.metadata[key])
        end
        open(joinpath(directory, "provenance.toml"), "w") do io
            TOML.print(io, provenance; sorted=true)
        end
    end

    artifact_dir = joinpath(root, "artifacts")
    report_dir = joinpath(root, "reports")
    mkpath(artifact_dir)
    mkpath(report_dir)
    archive = joinpath(artifact_dir, "$(id).tar.gz")
    isfile(archive) && error("refusing to overwrite $archive")
    deterministic_archive_artifact(tree, archive)
    report = Dict{String,Any}(
        "name" => String(id),
        "source_url" => spec.metadata["source_url"],
        "source_filename" => source_name,
        "source_sha256" => source_sha,
        "source_size_bytes" => filesize(source),
        "asset" => basename(archive),
        "archive_path" => abspath(archive),
        "archive_sha256" => file_sha256(archive),
        "archive_size_bytes" => filesize(archive),
        "git_tree_sha1" => string(tree),
    )
    if metadata_url !== nothing
        report["metadata_url"] = metadata_url
        report["metadata_sha256"] = metadata_sha
    end
    for key in ("license", "license_url", "citation")
        haskey(spec.metadata, key) && (report[key] = spec.metadata[key])
    end
    report_path = joinpath(report_dir, "$(id).toml")
    open(report_path, "w") do io
        TOML.print(io, report; sorted=true)
    end
    println("built $(id).tar.gz")
    return report_path
end

function report_files(path::String)
    isfile(path) && return [path]
    isdir(path) || error("report path does not exist: $path")
    return sort(filter(file -> endswith(file, ".toml"), readdir(path; join=true)))
end

function cmd_update_lock(args)
    length(args) in (0, 2) ||
        error("usage: catalog.jl update-lock [REPORT_OR_DIRECTORY RELEASE_DOWNLOAD_BASE]")
    reports = nothing
    base = nothing
    if length(args) == 2
        reports = abspath(args[1])
        base = rstrip(String(args[2]), '/')
        startswith(base, "https://") || error("release URL must use HTTPS")
    end

    lock_path = joinpath(_ROOT, "catalog", "ResourceLock.toml")
    old = isfile(lock_path) ? TOML.parsefile(lock_path) : Dict{String,Any}()
    resources = Dict{String,Any}(get(old, "resources", Dict{String,Any}()))
    if reports !== nothing
        files = report_files(reports)
        isempty(files) && error("no resource reports found")
        for file in files
            report = TOML.parsefile(file)
            name = String(report["name"])
            entry = Dict{String,Any}(
                "source_url" => report["source_url"],
                "source_filename" => report["source_filename"],
                "source_sha256" => report["source_sha256"],
                "source_size_bytes" => report["source_size_bytes"],
                "asset" => report["asset"],
                "archive_sha256" => report["archive_sha256"],
                "archive_size_bytes" => report["archive_size_bytes"],
                "git_tree_sha1" => report["git_tree_sha1"],
                "download_url" => "$base/$(report["asset"])",
            )
            for key in ("metadata_url", "metadata_sha256", "license", "license_url", "citation")
                haskey(report, key) && (entry[key] = report[key])
            end
            if haskey(resources, name) && resources[name] != entry
                error("lock entry $name already exists with different immutable content")
            end
            resources[name] = entry
        end
    end

    # The hand-maintained catalogue is authoritative for licensing metadata.
    for (name, raw) in collect(resources)
        spec = resource(Symbol(name))
        entry = Dict{String,Any}(raw)
        for key in ("license", "license_url", "citation")
            haskey(spec.metadata, key) && (entry[key] = spec.metadata[key])
        end
        resources[name] = entry
    end

    lock = Dict{String,Any}("version" => 1, "resources" => resources)
    open(lock_path, "w") do io
        println(io, "# Generated by the resource cache workflow. Do not edit by hand.")
        TOML.print(io, lock; sorted=true)
    end

    if reports !== nothing
        artifacts = Dict{String,Any}()
        for (name, raw) in resources
            entry = Dict{String,Any}(raw)
            artifacts[name] = Dict{String,Any}(
                "git-tree-sha1" => entry["git_tree_sha1"],
                "lazy" => true,
                "download" => [Dict{String,Any}(
                    "sha256" => entry["archive_sha256"],
                    "url" => entry["download_url"],
                )],
            )
        end
        open(joinpath(_ROOT, "Artifacts.toml"), "w") do io
            println(io, "# Generated from catalog/ResourceLock.toml. Do not edit by hand.")
            TOML.print(io, artifacts; sorted=true)
        end
        println("locked $(length(files)) resource(s); $(length(resources)) total")
    else
        println("synced license metadata for $(length(resources)) locked resource(s)")
    end
end

function main(args=ARGS)
    isempty(args) && (usage(); exit(1))
    command = popfirst!(args)
    if command == "add"
        cmd_add(args)
    elseif command == "validate"
        cmd_validate()
    elseif command == "uncached"
        cmd_uncached()
    elseif command == "scan" && length(args) == 1
        cmd_scan(only(args))
    elseif command == "build"
        cmd_build(args)
    elseif command == "update-lock"
        cmd_update_lock(args)
    else
        usage(stderr)
        exit(1)
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
