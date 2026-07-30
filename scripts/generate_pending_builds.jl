#!/usr/bin/env julia

using AstrodynamicsResources
using TOML

function main()
    pending = Dict{String,Any}[]
    for spec in list_resources(backend=:artifact, available=false)
        push!(pending, Dict{String,Any}(
            "id" => String(spec.id),
            "artifact_name" => spec.backend.artifact_name,
            "source_url" => get(spec.metadata, "source_url", ""),
            "source_filename" => get(spec.metadata, "source_filename", ""),
            "redistribution" => get(spec.metadata, "redistribution", "unreviewed"),
            "has_source_sha256" => haskey(spec.metadata, "source_sha256"),
            "ready" => haskey(spec.metadata, "source_sha256") &&
                       lowercase(String(get(spec.metadata, "redistribution", ""))) in
                       ("approved", "permitted", "public-domain", "public_domain"),
        ))
    end
    output = joinpath(@__DIR__, "..", "catalog", "pending_builds.toml")
    open(output, "w") do io
        TOML.print(io, Dict("pending" => pending); sorted=true)
    end
    println("wrote $(length(pending)) pending builds to $output")
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
