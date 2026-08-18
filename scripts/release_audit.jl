#!/usr/bin/env julia

using AstrodynamicsResources

json(values) = "[" * join(('"' * value * '"' for value in values), ",") * "]"

function published_assets(path::AbstractString)
    pairs = Set{Tuple{String, String}}()
    for raw in readlines(path)
        line = strip(raw)
        isempty(line) && continue
        fields = split(line, '\t'; limit = 2)
        length(fields) == 2 || error("invalid release asset line: $line")
        push!(pairs, (fields[1], fields[2]))
    end
    return pairs
end

function main(args = ARGS)
    length(args) in (1, 2) ||
        error("usage: release_audit.jl RELEASE_ASSET_FILE [--strict]")
    strict = length(args) == 2
    strict && args[2] != "--strict" &&
        error("usage: release_audit.jl RELEASE_ASSET_FILE [--strict]")

    published = published_assets(first(args))
    specs = list_resources(backend = :artifact)

    build = String[]
    adopt = String[]
    restore = String[]
    expected = Set{Tuple{String, String}}()

    for spec in specs
        pair = (
            AstrodynamicsResources.release_tag(spec),
            AstrodynamicsResources.resource_asset(spec),
        )
        push!(expected, pair)
        if spec.available
            pair in published || push!(restore, String(spec.id))
        elseif pair in published
            push!(adopt, String(spec.id))
        else
            push!(build, String(spec.id))
        end
    end

    orphans = sort!(String["$release/$asset" for (release, asset) in setdiff(published, expected)])
    sort!(build)
    sort!(adopt)
    sort!(restore)

    if haskey(ENV, "GITHUB_OUTPUT")
        open(ENV["GITHUB_OUTPUT"], "a") do io
            println(io, "build=", json(build))
            println(io, "build_count=", length(build))
            println(io, "adopt=", json(adopt))
            println(io, "adopt_count=", length(adopt))
            println(io, "restore=", json(restore))
            println(io, "restore_count=", length(restore))
        end
    end

    println("build: ", join(build, ", "))
    println("adopt existing archives: ", join(adopt, ", "))
    println("restore canonical copies: ", join(restore, ", "))
    isempty(orphans) || println("orphan release assets: ", join(orphans, ", "))

    strict && !isempty(restore) && error(
        "cached resources missing from their canonical releases:\n  " * join(restore, "\n  ")
    )
    return nothing
end

main()
