#!/usr/bin/env julia

using AstrodynamicsResources
using SHA
using TOML
import Pkg
import Tar

const ROOT = normpath(joinpath(@__DIR__, ".."))

file_sha256(path::AbstractString) = open(path, "r") do io
    bytes2hex(SHA.sha256(io))
end

function declared_sources(spec::ResourceSpec)
    if haskey(spec.metadata, "source_files")
        return [
            Dict{String, String}(
                "url" => String(item["url"]),
                "filename" => String(item["filename"]),
            ) for item in spec.metadata["source_files"]
        ]
    end
    return [
        Dict{String, String}(
            "url" => String(spec.metadata["source_url"]),
            "filename" => String(spec.metadata["source_filename"]),
        ),
    ]
end

function verify_file(path::AbstractString, expected_sha::AbstractString)
    isfile(path) || error("archive is missing $path")
    digest = file_sha256(path)
    digest == lowercase(String(expected_sha)) ||
        error("SHA-256 mismatch for $(basename(path)): expected $expected_sha, got $digest")
    return digest
end

function report_existing(id::Symbol, archive::AbstractString)
    spec = resource(id)
    spec.backend isa ArtifactBackend || error("$id is not an immutable resource")
    isfile(archive) || error("archive does not exist: $archive")
    basename(archive) == "$(id).tar.gz" ||
        error("unexpected asset name $(basename(archive)) for $id")

    report = mktempdir() do directory
        Tar.extract(`gzip -dc $archive`, directory)
        provenance_path = joinpath(directory, "provenance.toml")
        isfile(provenance_path) || error("$archive has no provenance.toml")
        provenance = TOML.parsefile(provenance_path)
        String(get(provenance, "name", "")) == String(id) ||
            error("archive provenance belongs to $(get(provenance, "name", "unknown")), not $id")

        declared = declared_sources(spec)
        String(get(provenance, "source_url", "")) == declared[1]["url"] ||
            error("archive source URL does not match the current catalogue for $id")
        String(get(provenance, "source_filename", "")) == declared[1]["filename"] ||
            error("archive source filename does not match the current catalogue for $id")

        result = Dict{String, Any}(
            "name" => String(id),
            "source_url" => declared[1]["url"],
            "source_filename" => declared[1]["filename"],
            "asset" => basename(archive),
            "archive_path" => abspath(archive),
            "archive_sha256" => file_sha256(archive),
            "archive_size_bytes" => filesize(archive),
            "git_tree_sha1" => bytes2hex(Pkg.GitTools.tree_hash(directory)),
        )

        if length(declared) == 1
            source_path = joinpath(directory, "data", declared[1]["filename"])
            expected_sha = String(get(provenance, "source_sha256", ""))
            isempty(expected_sha) && error("archive provenance has no source_sha256 for $id")
            result["source_sha256"] = verify_file(source_path, expected_sha)
            result["source_size_bytes"] = filesize(source_path)
        else
            archived = get(provenance, "files", Any[])
            length(archived) == length(declared) ||
                error("archive provenance file count differs from the catalogue for $id")
            files = Dict{String, Any}[]
            for (expected, raw) in zip(declared, archived)
                item = Dict{String, Any}(raw)
                String(item["url"]) == expected["url"] ||
                    error("archive source URL differs from the catalogue for $(expected["filename"]) ")
                String(item["filename"]) == expected["filename"] ||
                    error("archive source filename differs from the catalogue for $id")
                source_path = joinpath(directory, "data", expected["filename"])
                digest = verify_file(source_path, String(item["sha256"]))
                push!(
                    files,
                    Dict{String, Any}(
                        "filename" => expected["filename"],
                        "url" => expected["url"],
                        "sha256" => digest,
                        "size_bytes" => filesize(source_path),
                    ),
                )
            end
            result["files"] = files
        end

        metadata_url = get(spec.metadata, "metadata_url", nothing)
        if metadata_url !== nothing
            String(get(provenance, "metadata_url", "")) == String(metadata_url) ||
                error("archive metadata URL does not match the catalogue for $id")
            metadata_path = joinpath(directory, "metadata", basename(String(metadata_url)))
            expected_sha = String(get(provenance, "metadata_sha256", ""))
            isempty(expected_sha) && error("archive provenance has no metadata_sha256 for $id")
            result["metadata_url"] = String(metadata_url)
            result["metadata_sha256"] = verify_file(metadata_path, expected_sha)
        end

        for key in ("license", "license_url", "citation")
            haskey(spec.metadata, key) && (result[key] = spec.metadata[key])
        end
        result
    end

    report_dir = joinpath(ROOT, "build", "reports")
    mkpath(report_dir)
    report_path = joinpath(report_dir, "$(id).toml")
    open(report_path, "w") do io
        TOML.print(io, report; sorted = true)
    end
    println("reused published $(basename(archive)) for $id")
    return report_path
end

function main(args = ARGS)
    length(args) == 2 || error("usage: report_existing_resource.jl RESOURCE ARCHIVE")
    return report_existing(Symbol(args[1]), abspath(args[2]))
end

main()
