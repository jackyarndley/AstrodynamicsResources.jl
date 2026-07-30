#!/usr/bin/env julia

using TOML

function main(args=ARGS)
    manifest = isempty(args) ?
        joinpath(@__DIR__, "..", "catalog", "pending_builds.toml") : abspath(args[1])
    parsed = TOML.parsefile(manifest)
    failures = String[]
    for entry in get(parsed, "pending", Any[])
        get(entry, "ready", false) || continue
        id = String(entry["id"])
        command = `$(Base.julia_cmd()) --project=$(joinpath(@__DIR__)) $(joinpath(@__DIR__, "build_artifact.jl")) $id`
        try
            run(command)
        catch error
            push!(failures, "$id: $(sprint(showerror, error))")
        end
    end
    isempty(failures) || error("artifact builds failed:\n" * join(failures, "\n"))
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
