const _RESOURCE_REPOSITORY = "jackyarndley/AstrodynamicsResources.jl"

const RESOURCE_RELEASES = (
    "resources-ephemerides" => "Ephemerides",
    "resources-satellite-ephemerides" => "Satellite Ephemerides",
    "resources-star-catalogues" => "Star Catalogues",
    "resources-gravity-models" => "Gravity Models",
    "resources-textures" => "Textures",
    "resources-reference" => "Reference Data",
    "resources-shape-models" => "Shape Models",
)

function _release_tag(category::Symbol)
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

release_tag(spec::ResourceSpec) = _release_tag(spec.category)
release_tag(id::Symbol) = release_tag(resource(id))
resource_asset(spec::ResourceSpec) = "$(spec.id).tar.gz"
resource_asset(id::Symbol) = resource_asset(resource(id))

function release_title(tag::AbstractString)
    index = findfirst(item -> first(item) == tag, RESOURCE_RELEASES)
    index === nothing && throw(ArgumentError("unknown resource release $tag"))
    return last(RESOURCE_RELEASES[index])
end

function resource_download_url(spec::ResourceSpec)
    base = get(
        ENV, "ASTRODYNAMICS_RESOURCES_RELEASE_BASE",
        "https://github.com/$(_RESOURCE_REPOSITORY)/releases/download",
    )
    return "$(rstrip(base, '/'))/$(release_tag(spec))/$(resource_asset(spec))"
end
