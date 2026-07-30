#!/usr/bin/env julia

include(joinpath(@__DIR__, "lib", "discovery.jl"))
using .DiscoverySupport

const PCK = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/"
const FK = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/fk/satellites/"
const LSK = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/"

function main()
    current = vcat(hrefs(fetch_text(PCK)), hrefs(fetch_text(FK)),
                   hrefs(fetch_text(LSK)))
    watched = [
        "gm_de440.tpc", "pck00011.tpc", "geophysical.ker", "earth_fixed.tf",
        "naif0012.tls", "moon_pa_de440_200625.bpc",
        "moon_pa_de440_200625.cmt", "moon_de440_250416.tf",
        "moon_assoc_pa.tf", "moon_assoc_me.tf",
    ]
    discovered = sort(filter(name -> name in watched, current))
    ok = write_change_report(
        joinpath(@__DIR__, "..", "build", "reports", "naif-support");
        discovered, known=sort(watched),
        details=Dict("pck_root" => PCK, "fk_root" => FK, "lsk_root" => LSK,
                     "semantic_alias_policy" => "review required"),
    )
    ok || exit(2)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
