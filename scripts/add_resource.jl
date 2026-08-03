#!/usr/bin/env julia

function main(args=ARGS)
    2 <= length(args) <= 3 ||
        error("usage: add_resource.jl NAME URL [--live]")
    name, url = args[1:2]
    occursin(r"^[a-z][a-z0-9_]*$", name) || error("invalid resource name $name")
    startswith(url, "https://") || error("resource URL must use HTTPS")
    path = normpath(joinpath(@__DIR__, "..", "catalog", "Resources.toml"))
    text = read(path, String)
    occursin(Regex("(?m)^name = \\\"" * name * "\\\"$"), text) &&
        error("resource $name already exists")
    open(path, "a") do io
        println(io, "\n[[resource]]")
        println(io, "name = ", repr(name))
        println(io, "url = ", repr(url))
        length(args) == 3 && args[3] == "--live" && println(io, "live = true")
    end
    println("added $name; commit Resources.toml and the cache workflow will do the rest")
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
