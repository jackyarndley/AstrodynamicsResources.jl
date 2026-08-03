#!/usr/bin/env julia

using AstrodynamicsResources

length(ARGS) == 1 || error("usage: scan_release.jl ASSET_NAME_FILE")
published = Set(filter(!isempty, strip.(readlines(first(ARGS)))))
uncached = String[]
missing = String[]
for spec in list_resources(backend=:artifact)
    if !spec.available
        push!(uncached, String(spec.id))
    elseif !(String(spec.metadata["asset"]) in published)
        push!(missing, String(spec.id))
    end
end
sort!(uncached)
sort!(missing)
json(values) = "[" * join(('"' * value * '"' for value in values), ",") * "]"
if haskey(ENV, "GITHUB_OUTPUT")
    open(ENV["GITHUB_OUTPUT"], "a") do io
        println(io, "uncached=", json(uncached))
        println(io, "uncached_count=", length(uncached))
    end
end
println("uncached: ", join(uncached, ", "))
println("locked but missing from release: ", join(missing, ", "))
isempty(missing) || error(
    "locked resources are missing from the immutable release: " * join(missing, ", ") *
    ". Restore the exact locked archives; never rebuild or overwrite them.",
)
