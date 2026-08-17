#!/usr/bin/env julia

using AstrodynamicsResources

const RELEASE_TAGS = (
    "resources-ephemerides",
    "resources-satellite-ephemerides",
    "resources-star-catalogues",
    "resources-geopotential",
    "resources-textures",
    "resources-reference",
    "resources-shape-models",
)

function release_tag(spec::ResourceSpec)
    spec.backend isa ArtifactBackend ||
        throw(ArgumentError("$(spec.id) is live and does not belong in an immutable release"))

    category = spec.category
    category in (
        :ephemeris, :lagrange_ephemeris, :station_ephemeris,
        :asteroid_ephemeris, :comet_ephemeris,
    ) && return "resources-ephemerides"
    category in (:satellite_ephemeris, :tno_ephemeris) &&
        return "resources-satellite-ephemerides"
    category == :star_catalogue && return "resources-star-catalogues"
    category == :gravity && return "resources-geopotential"
    category == :texture && return "resources-textures"
    category == :geometry && return "resources-shape-models"
    return "resources-reference"
end

release_tag(id::Symbol) = release_tag(resource(id))

function usage(io::IO = stdout)
    print(
        io,
        """
        usage: resource_release.jl COMMAND [ARGS...]

        Commands:
          tag RESOURCE   Print the immutable release tag for RESOURCE.
          tags           Print all resource-family release tags, one per line.
          manifest       Print tab-separated ID, asset, and release tag for locked artifacts.
        """,
    )
end

function main(args = ARGS)
    isempty(args) && (usage(); exit(1))
    command = first(args)
    if command == "tag" && length(args) == 2
        return println(release_tag(Symbol(args[2])))
    elseif command == "tags" && length(args) == 1
        return foreach(println, RELEASE_TAGS)
    elseif command == "manifest" && length(args) == 1
        for spec in sort(list_resources(backend = :artifact); by = spec -> String(spec.id))
            spec.available || continue
            println(spec.id, '\t', spec.metadata["asset"], '\t', release_tag(spec))
        end
        return nothing
    end
    usage(stderr)
    return exit(1)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
