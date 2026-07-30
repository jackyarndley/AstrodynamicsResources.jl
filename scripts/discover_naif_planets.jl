#!/usr/bin/env julia

include(joinpath(@__DIR__, "lib", "discovery.jl"))
using .DiscoverySupport

const ROOT = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/planets/"
const REVIEWED = Set([
    "de430.bsp",
    "de432s.bsp",
    "de435.bsp",
    "de438.bsp",
    "de440.bsp",
    "de440s.bsp",
])

function main()
    html = fetch_text(ROOT)
    checksums = checksum_index(fetch_text(ROOT * "aa_checksums.txt"))
    discovered = filter(name -> name in REVIEWED, hrefs(html))
    entries = catalogue_entries(joinpath(@__DIR__, "..", "catalog", "ephemerides.toml"))
    known = sort([String(entry["source_filename"]) for entry in entries])
    changed = String[]
    for entry in entries
        filename = String(entry["source_filename"])
        expected = get(entry, "upstream_checksum", nothing)
        actual = get(checksums, filename, nothing)
        expected !== nothing && actual !== nothing &&
            lowercase(String(expected)) != actual && push!(changed, filename)
    end
    ok = write_change_report(
        joinpath(@__DIR__, "..", "build", "reports", "naif-planets");
        discovered, known, changed,
        details=Dict("excluded" => ["de431_part-1.bsp", "de431_part-2.bsp",
                                    "de441_part-1.bsp", "de441_part-2.bsp"],
                     "upstream_root" => ROOT),
    )
    ok || exit(2)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
