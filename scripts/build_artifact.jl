#!/usr/bin/env julia

using AstrodynamicsResources
using Downloads
using MD5
using SHA
using TOML
import Pkg

include(joinpath(@__DIR__, "lib", "artifact_archive.jl"))
using .ArtifactArchiveSupport

function file_sha256(path::String)
    open(path, "r") do io
        return bytes2hex(SHA.sha256(io))
    end
end

function file_md5(path::String)
    open(path, "r") do io
        return bytes2hex(MD5.md5(io))
    end
end

function reject_bad_source(spec::ResourceSpec, path::String)
    filesize(path) > 0 || error("upstream returned an empty file")
    head = open(path, "r") do io
        read(io, min(filesize(path), 512))
    end
    ascii = lowercase(String(copy(filter(byte -> byte < 0x80, head))))
    (occursin("<html", ascii) || occursin("<!doctype html", ascii)) &&
        error("upstream returned an HTML page instead of $(spec.metadata["source_filename"])")
    expected_name = lowercase(String(spec.metadata["source_filename"]))
    splitext(expected_name)[2] == splitext(lowercase(path))[2] ||
        error("unexpected source file extension")
end

function provenance(spec::ResourceSpec, digest::String)
    required = ("source_url", "source_filename", "retrieved_at", "citation",
                "license", "redistribution")
    all(key -> haskey(spec.metadata, key), required) ||
        error("$(spec.id) lacks required provenance metadata")
    return Dict{String,Any}(
        "resource_id" => String(spec.id),
        "source_url" => spec.metadata["source_url"],
        "source_filename" => spec.metadata["source_filename"],
        "source_sha256" => digest,
        "retrieved_at" => spec.metadata["retrieved_at"],
        "provider" => String(spec.provider),
        "version" => spec.version,
        "citation" => spec.metadata["citation"],
        "license" => spec.metadata["license"],
        "redistribution" => spec.metadata["redistribution"],
        "packager_version" => "AstrodynamicsResources.jl/0.1",
    )
end

function build(id::Symbol; output_root::String=joinpath(@__DIR__, "..", "build"))
    spec = resource(id)
    spec.backend isa ArtifactBackend || error("$id is not an artifact resource")
    redistribution = lowercase(String(get(spec.metadata, "redistribution", "")))
    redistribution in ("approved", "permitted", "public-domain", "public_domain") ||
        error("$id cannot be mirrored: redistribution status is $(repr(redistribution))")
    expected_sha = get(spec.metadata, "source_sha256", nothing)
    expected_sha === nothing &&
        error("$id has no independently reviewed source_sha256; refusing to build")

    mktempdir() do temp
        source_name = String(spec.metadata["source_filename"])
        downloaded = joinpath(temp, source_name)
        Downloads.download(String(spec.metadata["source_url"]), downloaded)
        reject_bad_source(spec, downloaded)
        actual_sha = file_sha256(downloaded)
        lowercase(String(expected_sha)) == actual_sha ||
            error("SHA-256 mismatch for $id: expected $expected_sha, got $actual_sha")

        algorithm = lowercase(String(get(spec.metadata, "upstream_checksum_algorithm", "")))
        upstream = get(spec.metadata, "upstream_checksum", nothing)
        if upstream !== nothing
            actual = algorithm == "md5" ? file_md5(downloaded) :
                     algorithm == "sha256" ? actual_sha :
                     error("unsupported upstream checksum algorithm $algorithm")
            lowercase(String(upstream)) == actual ||
                error("provider $algorithm checksum mismatch for $id")
        end

        hash = Pkg.Artifacts.create_artifact() do directory
            data_dir = joinpath(directory, "data")
            metadata_dir = joinpath(directory, "metadata")
            mkpath(data_dir)
            cp(downloaded, joinpath(data_dir, source_name); force=false)
            associated = get(spec.metadata, "associated_source_url", nothing)
            if associated !== nothing
                mkpath(metadata_dir)
                associated_name = basename(String(associated))
                associated_path = joinpath(temp, associated_name)
                Downloads.download(String(associated), associated_path)
                cp(associated_path, joinpath(metadata_dir, associated_name); force=false)
            end
            open(joinpath(directory, "provenance.toml"), "w") do io
                TOML.print(io, provenance(spec, actual_sha); sorted=true)
            end
        end

        artifact_dir = joinpath(output_root, "artifacts")
        report_dir = joinpath(output_root, "reports", "artifacts")
        mkpath(artifact_dir)
        mkpath(report_dir)
        archive = joinpath(artifact_dir, "$(id)-$(actual_sha).tar.gz")
        if isfile(archive)
            error("immutable archive already exists at $archive; refusing to overwrite")
        end
        deterministic_archive_artifact(hash, archive)
        archive_sha = file_sha256(archive)
        report = Dict{String,Any}(
            "resource_id" => String(id),
            "artifact_name" => spec.backend.artifact_name,
            "source_sha256" => actual_sha,
            "git_tree_sha1" => string(hash),
            "archive_path" => abspath(archive),
            "archive_sha256" => archive_sha,
            "archive_size_bytes" => filesize(archive),
        )
        report_path = joinpath(report_dir, "$(id)-$(actual_sha).toml")
        open(report_path, "w") do io
            TOML.print(io, report; sorted=true)
        end
        println("built $id")
        println("  tree:    ", hash)
        println("  archive: ", archive)
        println("  sha256:  ", archive_sha)
        return report_path
    end
end

function main(args=ARGS)
    isempty(args) && error("usage: build_artifact.jl RESOURCE_ID [OUTPUT_ROOT]")
    output = length(args) > 1 ? abspath(args[2]) : joinpath(@__DIR__, "..", "build")
    build(Symbol(args[1]); output_root=output)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
