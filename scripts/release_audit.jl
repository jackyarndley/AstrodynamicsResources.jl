#!/usr/bin/env julia

using AstrodynamicsResources
include(joinpath(@__DIR__, "lib", "resource_releases.jl"))
using .ResourceReleases

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
    length(args) == 1 || error("usage: release_audit.jl RELEASE_ASSET_FILE")
    published = published_assets(first(args))
    specs = list_resources(backend = :artifact)

    expected = Dict{String, String}()
    for spec in specs
        asset = spec.available ? String(spec.metadata["asset"]) : "$(spec.id).tar.gz"
        haskey(expected, asset) && error("duplicate release asset name $asset")
        expected[asset] = release_tag(spec)
    end

    missing = String[]
    migration_pending = String[]
    for spec in specs
        spec.available || continue
        target = release_tag(spec)
        asset = String(spec.metadata["asset"])
        (target, asset) in published && continue
        source = source_release(spec)
        if source !== nothing && source != target
            push!(migration_pending, "$(spec.id): $source/$asset -> $target/$asset")
        else
            push!(missing, "$(spec.id) -> $target/$asset")
        end
    end

    misplaced = String[]
    unknown = String[]
    for (release, asset) in published
        target = get(expected, asset, nothing)
        if target === nothing
            push!(unknown, "$release/$asset")
        elseif target != release
            push!(misplaced, "$release/$asset -> $target/$asset")
        end
    end

    uncached = sort!(String[String(spec.id) for spec in specs if !spec.available])
    sort!(missing)
    sort!(migration_pending)
    sort!(misplaced)
    sort!(unknown)

    if haskey(ENV, "GITHUB_OUTPUT")
        open(ENV["GITHUB_OUTPUT"], "a") do io
            println(io, "uncached=", json(uncached))
            println(io, "uncached_count=", length(uncached))
        end
    end

    println("uncached: ", join(uncached, ", "))
    isempty(migration_pending) || println(
        "legacy release migration pending:\n  ", join(migration_pending, "\n  ")
    )
    isempty(missing) || error("locked resources missing from canonical releases:\n  " * join(missing, "\n  "))
    isempty(misplaced) || error("assets published in the wrong canonical release:\n  " * join(misplaced, "\n  "))
    isempty(unknown) || error("unrecognised assets in canonical releases:\n  " * join(unknown, "\n  "))
    return nothing
end

main()
