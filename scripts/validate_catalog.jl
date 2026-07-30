#!/usr/bin/env julia

using AstrodynamicsResources
using TOML

function main()
    validate_catalog()
    pending_path = joinpath(@__DIR__, "..", "catalog", "pending_builds.toml")
    if isfile(pending_path)
        pending = get(TOML.parsefile(pending_path), "pending", Any[])
        pending_ids = Set(Symbol(entry["id"]) for entry in pending)
        expected = Set(spec.id for spec in list_resources(backend=:artifact)
                       if !spec.available)
        pending_ids == expected || error(
            "pending-build manifest differs from unavailable artifacts: " *
            "missing=$(collect(setdiff(expected, pending_ids))), " *
            "extra=$(collect(setdiff(pending_ids, expected)))"
        )
    end
    println("catalogue valid: $(length(list_resources())) resources")
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
