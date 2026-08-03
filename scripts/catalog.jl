#!/usr/bin/env julia

using AstrodynamicsResources

json(values) = "[" * join(('"' * value * '"' for value in values), ",") * "]"

function uncached()
    names = sort!(String[
        String(spec.id) for spec in list_resources(backend=:artifact) if !spec.available
    ])
    if haskey(ENV, "GITHUB_OUTPUT")
        open(ENV["GITHUB_OUTPUT"], "a") do io
            println(io, "resources=", json(names))
            println(io, "count=", length(names))
        end
    end
    println(json(names))
end

function scan(path::String)
    published = Set(filter(!isempty, strip.(readlines(path))))
    specs = list_resources(backend=:artifact)
    missing = sort!(String[
        String(spec.id) for spec in specs
        if spec.available && !(String(spec.metadata["asset"]) in published)
    ])
    names = sort!(String[String(spec.id) for spec in specs if !spec.available])
    if haskey(ENV, "GITHUB_OUTPUT")
        open(ENV["GITHUB_OUTPUT"], "a") do io
            println(io, "uncached=", json(names))
            println(io, "uncached_count=", length(names))
        end
    end
    println("uncached: ", join(names, ", "))
    isempty(missing) || error(
        "locked resources missing from the release: " * join(missing, ", "))
end

function validate()
    validate_catalog()
    immutable = list_resources(backend=:artifact)
    live = list_resources(backend=:scratch)
    println("catalogue valid: $(length(immutable) + length(live)) resources ",
            "($(length(immutable)) immutable, $(length(live)) live, ",
            "$(count(spec -> spec.available, immutable)) cached)")
end

command = isempty(ARGS) ? "" : popfirst!(ARGS)
command == "validate" ? validate() :
command == "uncached" ? uncached() :
command == "scan" && length(ARGS) == 1 ? scan(only(ARGS)) :
error("usage: catalog.jl validate|uncached|scan ASSET_FILE")
