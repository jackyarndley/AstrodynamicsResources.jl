#!/usr/bin/env julia

using AstrodynamicsResources

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
        println(spec.id, " ", file_sha256(path), " ", filesize(path))
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
