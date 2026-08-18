using AstrodynamicsResources
using Documenter
using DocumenterCitations
using DocumenterCodeBlocks

const RESOURCE_GROUPS = [
    "General ephemerides" => Set((
        :ephemeris, :lagrange_ephemeris, :station_ephemeris,
        :asteroid_ephemeris, :comet_ephemeris,
    )),
    "Satellite ephemerides" => Set((:satellite_ephemeris, :tno_ephemeris)),
    "Earth Orientation Parameters" => Set((:earth_orientation,)),
    "Space weather" => Set((:space_weather,)),
    "Star catalogues" => Set((:star_catalogue,)),
    "Gravity models" => Set((:gravity, :lunar_gravity)),
    "Planet textures" => Set((:texture,)),
    "Reference kernels and shape models" => Set((:constants, :orientation, :geometry, :data)),
]

function resource_table(io, specs)
    println(io, "| ID | Provider | Backend | Available | Source file | License |")
    println(io, "|:---|:---|:---|:---:|:---|:---|")
    for spec in specs
        source = get(spec.metadata, "source_filename", "")
        license = replace(String(get(spec.metadata, "license", "—")), "|" => "\\|")
        println(
            io, "| `:", spec.id, "` | ", spec.provider,
            " | ", AstrodynamicsResources.backend_symbol(spec.backend), " | ",
            spec.available ? "yes" : "pending", " | `", source, "` | ",
            license, " |",
        )
    end
end

reference = joinpath(@__DIR__, "src", "resources.md")
open(reference, "w") do io
    println(io, "# Resource catalogue")
    println(io)
    println(io, "This page is generated from the local TOML catalogues. `Available` means")
    println(io, "an immutable resource has complete integrity metadata, or a live endpoint")
    println(io, "is exposed; it does not mean the resource is cached on this machine.")
    println(io)
    specs = list_resources()
    shown = Set{Symbol}()
    for (title, categories) in RESOURCE_GROUPS
        grouped = filter(spec -> spec.category in categories, specs)
        isempty(grouped) && continue
        println(io, "## ", title)
        println(io)
        resource_table(io, grouped)
        println(io)
        union!(shown, getfield.(grouped, :id))
    end
    remaining = filter(spec -> !(spec.id in shown), specs)
    if !isempty(remaining)
        println(io, "## Other resources")
        println(io)
        resource_table(io, remaining)
    end
end

bib = CitationBibliography(joinpath(@__DIR__, "src", "refs.bib"))

makedocs(
    sitename = "AstrodynamicsResources.jl",
    format = Documenter.HTML(
        edit_link = "main",
        repolink = "https://github.com/jackyarndley/AstrodynamicsResources.jl",
    ),
    modules = [AstrodynamicsResources],
    remotes = nothing,
    plugins = [bib, CodeBlocks()],
    pages = [
        "Home" => "index.md",
        "Resources" => [
            "General ephemerides" => "general_ephemerides.md",
            "Satellite ephemerides" => "satellite_ephemerides.md",
            "Earth Orientation Parameters" => "earth_orientation.md",
            "Space weather" => "space_weather.md",
            "Star catalogues" => "star_catalogues.md",
            "Gravity models" => "geopotential_models.md",
            "Planet textures" => "planet_textures.md",
            "Reference kernels and shape models" => "reference_data.md",
            "Complete catalogue" => "resources.md",
        ],
        "API" => "api.md",
        "Contributing resources" => "contributing.md",
        "References" => "references.md",
    ],
    checkdocs = :exports,
)
