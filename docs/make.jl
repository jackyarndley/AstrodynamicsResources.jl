using AstrodynamicsResources
using Documenter

reference = joinpath(@__DIR__, "src", "resources.md")
open(reference, "w") do io
    println(io, "# Resource reference")
    println(io)
    println(io, "This page is generated from the local TOML catalogue. `Available` means")
    println(io, "a verified production artifact binding or live endpoint is exposed; it")
    println(io, "does not mean the resource is currently cached.")
    println(io)
    println(io, "| ID | Category | Provider | Backend | Available | Source file |")
    println(io, "|:---|:---|:---|:---|:---:|:---|")
    for spec in list_resources()
        source = get(spec.metadata, "source_filename", "")
        println(io, "| `:", spec.id, "` | ", spec.category, " | ", spec.provider,
                " | ", AstrodynamicsResources.backend_symbol(spec.backend), " | ",
                spec.available ? "yes" : "pending", " | `", source, "` |")
    end
end

makedocs(
    sitename="AstrodynamicsResources.jl",
    format=Documenter.HTML(edit_link=nothing, repolink=nothing),
    modules=[AstrodynamicsResources],
    remotes=nothing,
    pages=[
        "Home" => "index.md",
        "Using resources" => "usage.md",
        "Lunar orientation" => "lunar.md",
        "Operations and provenance" => "operations.md",
        "Contributing resources" => "contributing.md",
        "Resource reference" => "resources.md",
        "API" => "api.md",
    ],
    checkdocs=:exports,
)
