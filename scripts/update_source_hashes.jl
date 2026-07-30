#!/usr/bin/env julia

using AstrodynamicsResources
using Dates
using TOML

include(joinpath(@__DIR__, "lib", "source_cache.jl"))
using .SourceCache

const CATALOG_DIR = normpath(joinpath(@__DIR__, "..", "catalog"))

function set_catalog_value!(id::String, key::String, value)
    for file in sort(readdir(CATALOG_DIR; join=true))
        endswith(file, ".toml") || continue
        basename(file) in ("bundles.toml", "pending_builds.toml") && continue
        lines = readlines(file; keep=true)
        starts = findall(i -> strip(lines[i]) == "[[resource]]", eachindex(lines))
        for (position, first_line) in enumerate(starts)
            last_line = position == length(starts) ? length(lines) : starts[position + 1] - 1
            section = first_line:last_line
            section_lines = collect(section)
            id_offset = findfirst(i -> strip(lines[i]) == "id = \"$(id)\"", section_lines)
            id_offset === nothing && continue
            id_line = first_line + id_offset - 1
            existing_offset =
                findfirst(i -> startswith(strip(lines[i]), key * " ="), section_lines)
            existing = existing_offset === nothing ? nothing :
                       first_line + existing_offset - 1
            newline = endswith(lines[first_line], "\r\n") ? "\r\n" : "\n"
            encoded = value isa AbstractString ? "\"$(value)\"" : string(value)
            replacement = "$key = $encoded" * newline
            if existing === nothing
                source_offset =
                    findfirst(i -> startswith(strip(lines[i]), "source_filename ="), section_lines)
                source_line = source_offset === nothing ? nothing :
                              first_line + source_offset - 1
                insert_at = source_line === nothing ? id_line : source_line
                insert!(lines, insert_at + 1, replacement)
            else
                lines[existing] = replacement
            end
            temporary = file * ".tmp"
            open(temporary, "w") do io
                foreach(line -> write(io, line), lines)
            end
            mv(temporary, file; force=true)
            return file
        end
    end
    error("could not find catalogue entry for $id")
end

function write_report!(record)
    path = joinpath(@__DIR__, "..", "build", "reports", "source-hashes",
                    String(record["id"]) * ".toml")
    mkpath(dirname(path))
    temporary = path * ".tmp"
    open(temporary, "w") do io
        TOML.print(io, Dict(
            "generated_at" => Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
            "resource" => record,
        ); sorted=true)
    end
    mv(temporary, path; force=true)
    return path
end

function main(args=ARGS)
    cache_root = abspath(get(ENV, "ASTRODYNAMICS_RESOURCES_SOURCE_CACHE",
                             joinpath(@__DIR__, "..", "build", "source-cache")))
    accept_size_changes = "--accept-size-changes" in args
    requested = Set(Symbol.(filter(arg -> !startswith(arg, "--"), args)))
    candidates = sort(filter(list_resources(backend=:artifact)) do spec
        !haskey(spec.metadata, "source_sha256") &&
            (isempty(requested) || spec.id in requested)
    end; by=spec -> (Int(get(spec.metadata, "size_bytes", 0)), String(spec.id)))
    isempty(candidates) && error("no unhashed artifact resources matched")

    for (index, spec) in enumerate(candidates)
        println("[$index/$(length(candidates))] fetching $(spec.id) ($(get(spec.metadata, "size_bytes", 0)) bytes)")
        cached = fetch_verified_source(spec.metadata; cache_root, require_sha256=false,
                                       verify_size=!accept_size_changes)
        digest = file_sha256(cached)
        old_size = Int(get(spec.metadata, "size_bytes", filesize(cached)))
        new_size = filesize(cached)
        if old_size != new_size
            accept_size_changes ||
                error("size changed for $(spec.id): expected $old_size bytes, got $new_size; " *
                      "inspect upstream and rerun with --accept-size-changes")
            set_catalog_value!(String(spec.id), "size_bytes", new_size)
            println("  reviewed size change: $old_size -> $new_size bytes")
        end
        file = set_catalog_value!(String(spec.id), "source_sha256", digest)
        record = Dict(
            "id" => String(spec.id),
            "source_filename" => spec.metadata["source_filename"],
            "source_sha256" => digest,
            "size_bytes" => new_size,
            "previous_size_bytes" => old_size,
            "cache_path" => cached,
            "catalog_file" => relpath(file, joinpath(@__DIR__, "..")),
        )
        report = write_report!(record)
        println("  verified $digest")
        println("  progress report: $report")
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
