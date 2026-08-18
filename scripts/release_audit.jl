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

function emit_uncached(specs, published)
    uncached = sort!(String[String(spec.id) for spec in specs if !spec.available])
    reusable = sort!(
        String[
            String(spec.id) for spec in specs
                if !spec.available && (release_tag(spec), "$(spec.id).tar.gz") in published
        ]
    )
    if haskey(ENV, "GITHUB_OUTPUT")
        open(ENV["GITHUB_OUTPUT"], "a") do io
            println(io, "uncached=", json(uncached))
            println(io, "uncached_count=", length(uncached))
            println(io, "reusable=", json(reusable))
            println(io, "reusable_count=", length(reusable))
        end
    end
    println("unlocked: ", join(uncached, ", "))
    isempty(reusable) || println("already published and reusable: ", join(reusable, ", "))
    return nothing
end

function cache_audit(specs, published)
    missing = String[]
    for spec in specs
        spec.available || continue
        source = source_release(spec)
        source === nothing && error("$(spec.id) has no release-backed download URL")
        asset = String(spec.metadata["asset"])
        (source, asset) in published || push!(missing, "$(spec.id) -> $source/$asset")
    end
    sort!(missing)
    isempty(missing) || error(
        "locked resources missing from their configured releases:\n  " * join(missing, "\n  ")
    )
    return nothing
end

function canonical_audit(specs, published)
    expected = Dict{String, String}()
    for spec in specs
        asset = spec.available ? String(spec.metadata["asset"]) : "$(spec.id).tar.gz"
        haskey(expected, asset) && error("duplicate release asset name $asset")
        expected[asset] = release_tag(spec)
    end

    missing = String[]
    for spec in specs
        spec.available || continue
        target = release_tag(spec)
        asset = String(spec.metadata["asset"])
        (target, asset) in published || push!(missing, "$(spec.id) -> $target/$asset")
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

    sort!(missing)
    sort!(misplaced)
    sort!(unknown)
    isempty(missing) || error(
        "locked resources missing from canonical releases:\n  " * join(missing, "\n  ")
    )
    isempty(misplaced) || error(
        "assets published in the wrong canonical release:\n  " * join(misplaced, "\n  ")
    )
    isempty(unknown) || error(
        "unrecognised assets in canonical releases:\n  " * join(unknown, "\n  ")
    )
    return nothing
end

function main(args = ARGS)
    1 <= length(args) <= 2 ||
        error("usage: release_audit.jl RELEASE_ASSET_FILE [cache|canonical]")
    mode = length(args) == 2 ? args[2] : "cache"
    mode in ("cache", "canonical") || error("unknown audit mode $mode")

    published = published_assets(first(args))
    specs = list_resources(backend = :artifact)
    emit_uncached(specs, published)
    mode == "cache" ? cache_audit(specs, published) : canonical_audit(specs, published)
    return nothing
end

main()
