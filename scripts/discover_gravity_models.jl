#!/usr/bin/env julia

using Downloads
using TOML

function main()
    path = joinpath(@__DIR__, "..", "catalog", "candidates", "gravity.toml")
    candidates = get(TOML.parsefile(path), "candidate", Any[])
    failures = String[]
    for candidate in candidates
        url = String(candidate["authoritative_page"])
        response = try
            Downloads.request(url; method="HEAD", timeout=30)
        catch error
            push!(failures, "$(candidate["id"]): $(sprint(showerror, error))")
            continue
        end
        200 <= response.status < 400 ||
            push!(failures, "$(candidate["id"]): HTTP $(response.status)")
    end
    report = joinpath(@__DIR__, "..", "build", "reports", "gravity-models.toml")
    mkpath(dirname(report))
    open(report, "w") do io
        TOML.print(io, Dict("checked" => length(candidates),
                            "failures" => sort(failures)); sorted=true)
    end
    isempty(failures) || exit(2)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
