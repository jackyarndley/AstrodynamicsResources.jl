module ResourceReleases

using AstrodynamicsResources

export RELEASES, release_tag, release_title, source_release

const RELEASES = (
    "resources-ephemerides" => "Ephemerides",
    "resources-satellite-ephemerides" => "Satellite Ephemerides",
    "resources-star-catalogues" => "Star Catalogues",
    "resources-gravity-models" => "Gravity Models",
    "resources-textures" => "Textures",
    "resources-reference" => "Reference Data",
    "resources-shape-models" => "Shape Models",
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
    category in (:gravity, :lunar_gravity) && return "resources-gravity-models"
    category == :texture && return "resources-textures"
    category == :geometry && return "resources-shape-models"
    return "resources-reference"
end

release_tag(id::Symbol) = release_tag(resource(id))

function release_title(tag::AbstractString)
    index = findfirst(item -> first(item) == tag, RELEASES)
    index === nothing && throw(ArgumentError("unknown resource release $tag"))
    return last(RELEASES[index])
end

function source_release(spec::ResourceSpec)
    url = get(spec.metadata, "download_url", nothing)
    url === nothing && return nothing
    result = match(r"/releases/download/([^/]+)/", String(url))
    return result === nothing ? nothing : String(result.captures[1])
end

end
