#!/usr/bin/env julia

using AstrodynamicsResources
using TOML

include(joinpath(@__DIR__, "lib", "catalog_editor.jl"))
using .CatalogEditor

const ROOT = normpath(joinpath(@__DIR__, ".."))
const LOCK = joinpath(ROOT, "catalog", "ResourceLock.toml")

function source_release(entry::Dict{String, Any})
    url = String(entry["download_url"])
    result = match(r"/releases/download/([^/]+)/", url)
    result === nothing && error("lock entry has no GitHub release URL: $url")
    return String(result.captures[1])
end

function declared_resource(name::String)
    try
        return resource(Symbol(name))
    catch exception
        exception isa KeyError || rethrow(exception)
        return nothing
    end
end

function reports()
    parsed = TOML.parsefile(LOCK)
    resources = Dict{String, Any}(get(parsed, "resources", Dict{String, Any}()))
    output = Dict{String, Any}[]
    for name in sort!(collect(keys(resources)))
        spec = declared_resource(name)
        spec === nothing && continue
        entry = Dict{String, Any}(resources[name])
        report = Dict{String, Any}(
            "name" => name,
            "source_url" => entry["source_url"],
            "source_filename" => entry["source_filename"],
            "asset" => entry["asset"],
            "archive_sha256" => entry["archive_sha256"],
            "archive_size_bytes" => entry["archive_size_bytes"],
            "git_tree_sha1" => entry["git_tree_sha1"],
        )
        if haskey(entry, "files")
            report["files"] = entry["files"]
        else
            report["source_sha256"] = entry["source_sha256"]
            haskey(entry, "source_size_bytes") &&
                (report["source_size_bytes"] = entry["source_size_bytes"])
        end
        for key in ("metadata_url", "metadata_sha256")
            haskey(entry, key) && (report[key] = entry[key])
        end
        push!(output, report)
    end
    return output
end

function manifest()
    parsed = TOML.parsefile(LOCK)
    resources = Dict{String, Any}(get(parsed, "resources", Dict{String, Any}()))
    for name in sort!(collect(keys(resources)))
        spec = declared_resource(name)
        spec === nothing && continue
        entry = Dict{String, Any}(resources[name])
        println(
            name, '\t', entry["asset"], '\t',
            AstrodynamicsResources.release_tag(spec), '\t', source_release(entry),
        )
    end
    return nothing
end

function apply()
    changed = update_reports!(ROOT, reports())
    println("inlined immutable metadata into $(length(changed)) catalogue file(s)")
    return nothing
end

function main(args = ARGS)
    length(args) == 1 || error("usage: inline_resource_metadata.jl manifest|apply")
    first(args) == "manifest" && return manifest()
    first(args) == "apply" && return apply()
    error("usage: inline_resource_metadata.jl manifest|apply")
end

main()
