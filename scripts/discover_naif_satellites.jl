#!/usr/bin/env julia

include(joinpath(@__DIR__, "lib", "discovery.jl"))
using .DiscoverySupport
using SHA

const SPK_ROOT = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/satellites/"
const FK_ROOT = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/fk/satellites/"

function main()
    spk_html = fetch_text(SPK_ROOT)
    fk_html = fetch_text(FK_ROOT)
    checksums = checksum_index(fetch_text(SPK_ROOT * "aa_checksums.txt"))
    # Reading these is intentional: they are small authoritative metadata files,
    # not the kernels themselves.
    summaries = fetch_text(SPK_ROOT * "aa_summaries.txt")
    readme = fetch_text(SPK_ROOT * "AAREADME_Satellite_SPKs")
    discovered = filter(name -> endswith(lowercase(name), ".bsp"), hrefs(spk_html))
    frames = filter(name -> endswith(lowercase(name), "_nameid.tf"), hrefs(fk_html))

    entries = catalogue_entries(joinpath(@__DIR__, "..", "catalog", "satellites.toml"))
    append!(entries, catalogue_entries(
        joinpath(@__DIR__, "..", "catalog", "candidates", "oversized.toml");
        table="candidate",
    ))
    known_spks = sort([String(entry["source_filename"]) for entry in entries
                       if endswith(lowercase(String(entry["source_filename"])), ".bsp")])
    changed = String[]
    for entry in entries
        filename = String(entry["source_filename"])
        endswith(lowercase(filename), ".bsp") || continue
        expected = get(entry, "upstream_checksum", nothing)
        actual = get(checksums, filename, nothing)
        actual === nothing && push!(changed, filename * " (missing checksum)")
        expected !== nothing && actual !== nothing &&
            lowercase(String(expected)) != actual && push!(changed, filename)
    end

    ok = write_change_report(
        joinpath(@__DIR__, "..", "build", "reports", "naif-satellites");
        discovered, known=known_spks, changed,
        details=Dict(
            "upstream_root" => SPK_ROOT,
            "associated_nameid_frames" => frames,
            "summary_sha256" => bytes2hex(SHA.sha256(codeunits(summaries))),
            "readme_bytes" => ncodeunits(readme),
            "policy" => "No recommendation or latest alias is generated.",
        ),
    )
    ok || exit(2)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
