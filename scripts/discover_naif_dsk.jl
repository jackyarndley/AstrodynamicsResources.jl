#!/usr/bin/env julia

include(joinpath(@__DIR__, "lib", "discovery.jl"))
using .DiscoverySupport

const ROOT = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/dsk/"

function discover_directory(url::String, relative::String="")
    result = String[]
    for link in hrefs(fetch_text(url))
        (startswith(link, "/") || startswith(link, "http")) && continue
        if endswith(link, "/")
            append!(result, discover_directory(url * link, relative * link))
        elseif endswith(lowercase(link), ".bds")
            push!(result, relative * link)
        end
    end
    sort!(result)
    return result
end

function main()
    discovered = String[]
    for category in ("asteroids/", "comets/", "planets/", "satellites/")
        append!(discovered, discover_directory(ROOT * category, category))
    end
    entries = catalogue_entries(joinpath(@__DIR__, "..", "catalog", "geometry.toml"))
    known = sort([replace(String(entry["source_url"]), ROOT => "") for entry in entries])
    ok = write_change_report(
        joinpath(@__DIR__, "..", "build", "reports", "naif-dsk");
        discovered=sort(discovered), known,
        details=Dict("upstream_root" => ROOT,
                     "publication_policy" => "Review only; never publishes artifacts."),
    )
    ok || exit(2)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
