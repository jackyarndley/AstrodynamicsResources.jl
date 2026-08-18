#!/usr/bin/env julia

using AstrodynamicsResources

function usage(io::IO = stdout)
    print(
        io,
        """
        usage: resource_release.jl COMMAND [ARGS...]

        Commands:
          tag RESOURCE     Print the canonical immutable release tag for RESOURCE.
          title RELEASE    Print the display title for a resource release.
          tags             Print all canonical resource-family release tags.
          releases         Print tab-separated release tag and display title pairs.
          manifest         Print ID, asset, release, and availability for immutable resources.
        """,
    )
end

function main(args = ARGS)
    isempty(args) && (usage(); exit(1))
    command = first(args)
    if command == "tag" && length(args) == 2
        return println(AstrodynamicsResources.release_tag(Symbol(args[2])))
    elseif command == "title" && length(args) == 2
        return println(AstrodynamicsResources.release_title(args[2]))
    elseif command == "tags" && length(args) == 1
        return foreach(item -> println(first(item)), AstrodynamicsResources.RESOURCE_RELEASES)
    elseif command == "releases" && length(args) == 1
        return foreach(
            item -> println(first(item), '\t', last(item)),
            AstrodynamicsResources.RESOURCE_RELEASES,
        )
    elseif command == "manifest" && length(args) == 1
        for spec in sort(list_resources(backend = :artifact); by = spec -> String(spec.id))
            println(
                spec.id, '\t', AstrodynamicsResources.resource_asset(spec), '\t',
                AstrodynamicsResources.release_tag(spec), '\t', spec.available,
            )
        end
        return nothing
    end
    usage(stderr)
    return exit(1)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
