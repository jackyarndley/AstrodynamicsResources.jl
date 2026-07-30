#!/usr/bin/env julia

using AstrodynamicsResources
using Dates
using TOML

include(joinpath(@__DIR__, "lib", "source_cache.jl"))
using .SourceCache

function main(args=ARGS)
    isempty(args) && error("usage: prefetch_sources.jl RESOURCE_ID...")
    cache_root = abspath(get(ENV, "ASTRODYNAMICS_RESOURCES_SOURCE_CACHE",
                             joinpath(@__DIR__, "..", "build", "source-cache")))
    for raw_id in args
        spec = resource(Symbol(raw_id))
        spec.backend isa ArtifactBackend ||
            error("$(spec.id) is not an immutable artifact resource")
        path = fetch_verified_source(spec.metadata; cache_root,
                                     require_sha256=false)
        digest = file_sha256(path)
        report = joinpath(@__DIR__, "..", "build", "reports", "source-hashes",
                          String(spec.id) * ".toml")
        mkpath(dirname(report))
        open(report, "w") do io
            TOML.print(io, Dict(
                "generated_at" => Dates.format(now(UTC),
                                               dateformat"yyyy-mm-ddTHH:MM:SSZ"),
                "resource" => Dict(
                    "id" => String(spec.id),
                    "source_filename" => spec.metadata["source_filename"],
                    "source_sha256" => digest,
                    "size_bytes" => filesize(path),
                    "cache_path" => path,
                ),
            ); sorted=true)
        end
        println(spec.id, " ", digest, " ", filesize(path))
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
