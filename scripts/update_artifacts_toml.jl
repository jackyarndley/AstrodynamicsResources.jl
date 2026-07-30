#!/usr/bin/env julia

using SHA
using TOML
import Pkg

function mark_available!(id::String)
    catalog = joinpath(@__DIR__, "..", "catalog")
    for file in sort(readdir(catalog; join=true))
        endswith(file, ".toml") || continue
        basename(file) in ("bundles.toml", "pending_builds.toml") && continue
        lines = readlines(file; keep=true)
        starts = findall(index -> strip(lines[index]) == "[[resource]]", eachindex(lines))
        for (position, first_line) in enumerate(starts)
            last_line = position == length(starts) ? length(lines) : starts[position + 1] - 1
            section = first_line:last_line
            section_lines = collect(section)
            any(index -> strip(lines[index]) == "id = \"$(id)\"", section_lines) || continue
            availability_offset =
                findfirst(index -> startswith(strip(lines[index]), "available ="),
                          section_lines)
            availability = availability_offset === nothing ? nothing :
                           first_line + availability_offset - 1
            if availability === nothing
                id_offset =
                    findfirst(index -> strip(lines[index]) == "id = \"$(id)\"", section_lines)
                id_line = first_line + id_offset - 1
                insert!(lines, id_line + 1, "available = true\n")
            else
                newline = endswith(lines[availability], "\r\n") ? "\r\n" : "\n"
                lines[availability] = "available = true" * newline
            end
            open(file, "w") do io
                foreach(line -> write(io, line), lines)
            end
            return file
        end
    end
    error("could not find catalogue entry for $id")
end

function main(args=ARGS)
    length(args) == 2 ||
        error("usage: update_artifacts_toml.jl BUILD_REPORT IMMUTABLE_DOWNLOAD_URL")
    report = TOML.parsefile(abspath(args[1]))
    url = String(args[2])
    startswith(url, "https://") || error("artifact download URL must use HTTPS")
    occursin(r"/(main|master)/", url) &&
        error("mutable branch URLs are forbidden for artifact storage")
    toml = joinpath(@__DIR__, "..", "Artifacts.toml")
    existing = TOML.parsefile(toml)
    name = String(report["artifact_name"])
    haskey(existing, name) &&
        error("$name is already bound; immutable bindings are never overwritten")
    hash = Base.SHA1(hex2bytes(String(report["git_tree_sha1"])))
    download_info = [(url, String(report["archive_sha256"]))]
    Pkg.Artifacts.bind_artifact!(toml, name, hash; download_info,
                                 lazy=true, force=false)
    catalog_file = mark_available!(String(report["resource_id"]))
    println("bound $name as a lazy artifact")
    println("marked resource available in $catalog_file")
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
