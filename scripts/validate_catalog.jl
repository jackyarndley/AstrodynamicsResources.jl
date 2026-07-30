#!/usr/bin/env julia

using AstrodynamicsResources
using TOML

function main()
    validate_catalog()
    oversized_path = joinpath(@__DIR__, "..", "catalog", "candidates",
                              "oversized.toml")
    if isfile(oversized_path)
        parsed = TOML.parsefile(oversized_path)
        limit = Int(parsed["maximum_active_size_bytes"])
        candidates = get(parsed, "candidate", Any[])
        ids = String[String(entry["id"]) for entry in candidates]
        length(ids) == length(unique(ids)) ||
            error("oversized candidate catalogue contains duplicate IDs")
        active = Set(String(spec.id) for spec in list_resources())
        isempty(intersect(Set(ids), active)) ||
            error("oversized candidate IDs collide with active resources")
        required = ("source_url", "source_filename", "size_bytes",
                    "candidate_reason", "source_catalog")
        for entry in candidates
            missing = filter(key -> !haskey(entry, key), required)
            isempty(missing) ||
                error("oversized candidate $(entry["id"]) lacks $(join(missing, ", "))")
            Int(entry["size_bytes"]) > limit ||
                error("oversized candidate $(entry["id"]) does not exceed the limit")
        end
    end
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
