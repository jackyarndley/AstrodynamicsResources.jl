#!/usr/bin/env julia

using AstrodynamicsResources

names = String[
    String(spec.id) for spec in list_resources(backend=:artifact) if !spec.available
]
sort!(names)
json = "[" * join(('"' * name * '"' for name in names), ",") * "]"
if haskey(ENV, "GITHUB_OUTPUT")
    open(ENV["GITHUB_OUTPUT"], "a") do io
        println(io, "resources=", json)
        println(io, "count=", length(names))
    end
end
println(json)
