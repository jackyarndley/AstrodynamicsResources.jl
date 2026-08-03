#!/usr/bin/env julia

using AstrodynamicsResources
using TOML
import Pkg

include(joinpath(@__DIR__, "lib", "artifact_archive.jl"))
include(joinpath(@__DIR__, "lib", "source_cache.jl"))
using .ArtifactArchiveSupport
using .SourceCache

function build(id::Symbol; output_root::String=joinpath(@__DIR__, "..", "build"))
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
        joinpath(output_root, "source-cache")))
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
        if metadata_url !== nothing
            provenance["metadata_url"] = metadata_url
            provenance["metadata_sha256"] = metadata_sha
        end
        open(joinpath(directory, "provenance.toml"), "w") do io
            TOML.print(io, provenance; sorted=true)
        end
    end

    artifact_dir = joinpath(output_root, "artifacts")
    report_dir = joinpath(output_root, "reports")
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
    report_path = joinpath(report_dir, "$(id).toml")
    open(report_path, "w") do io
        TOML.print(io, report; sorted=true)
    end
    println("built $(id).tar.gz")
    return report_path
end

function main(args=ARGS)
    isempty(args) && error("usage: build_artifact.jl NAME [OUTPUT_ROOT]")
    root = length(args) > 1 ? abspath(args[2]) : joinpath(@__DIR__, "..", "build")
    build(Symbol(first(args)); output_root=root)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
