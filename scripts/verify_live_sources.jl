#!/usr/bin/env julia

using Downloads
using TOML

function main()
    files = ["constants.toml", "environment.toml", "live.toml"]
    results = Dict{String,Any}()
    failed = false
    for file in files
        parsed = TOML.parsefile(joinpath(@__DIR__, "..", "catalog", file))
        for entry in get(parsed, "resource", Any[])
            get(entry, "backend", "") == "scratch" || continue
            id = String(entry["id"])
            url = first(String.(entry["urls"]))
            status = try
                response = Downloads.request(url; method="HEAD", timeout=30)
                response.status
            catch
                0
            end
            plausible = 200 <= status < 400
            results[id] = Dict("url" => url, "status" => status,
                               "plausible" => plausible)
            failed |= !plausible
        end
    end
    report = joinpath(@__DIR__, "..", "build", "reports", "live-sources.toml")
    mkpath(dirname(report))
    open(report, "w") do io
        TOML.print(io, Dict("resource" => results); sorted=true)
    end
    failed && exit(2)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
