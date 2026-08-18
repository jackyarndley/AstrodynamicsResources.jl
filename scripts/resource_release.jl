#!/usr/bin/env julia

using AstrodynamicsResources
include(joinpath(@__DIR__, "lib", "resource_releases.jl"))
using .ResourceReleases

function usage(io::IO = stdout)
    print(
        io,
        """
        usage: resource_release.jl COMMAND [ARGS...]

        Commands:
          tag RESOURCE     Print the immutable release tag for RESOURCE.
          title RELEASE    Print the display title for a resource release.
          tags             Print all canonical resource-family release tags.
          source-tags      Print release tags currently referenced by locked artifacts.
          releases         Print tab-separated release tag and display title pairs.
          manifest         Print ID, asset, target release, and current source release.
        """,
    )
end

function source_tags()
    tags = String[]
    for spec in list_resources(backend = :artifact)
        spec.available || continue
        source = source_release(spec)
        source === nothing && error("$(spec.id) has no release-backed download URL")
        push!(tags, source)
    end
    return sort!(unique!(tags))
end

function main(args = ARGS)
    isempty(args) && (usage(); exit(1))
    command = first(args)
    if command == "tag" && length(args) == 2
        return println(release_tag(Symbol(args[2])))
    elseif command == "title" && length(args) == 2
        return println(release_title(args[2]))
    elseif command == "tags" && length(args) == 1
        return foreach(item -> println(first(item)), RELEASES)
    elseif command == "source-tags" && length(args) == 1
        return foreach(println, source_tags())
    elseif command == "releases" && length(args) == 1
        return foreach(item -> println(first(item), '\t', last(item)), RELEASES)
    elseif command == "manifest" && length(args) == 1
        for spec in sort(list_resources(backend = :artifact); by = spec -> String(spec.id))
            spec.available || continue
            source = source_release(spec)
            source === nothing && error("$(spec.id) has no release-backed download URL")
            println(
                spec.id, '\t', spec.metadata["asset"], '\t',
                release_tag(spec), '\t', source,
            )
        end
        return nothing
    end
    usage(stderr)
    return exit(1)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
