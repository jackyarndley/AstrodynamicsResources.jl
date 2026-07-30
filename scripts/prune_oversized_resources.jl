#!/usr/bin/env julia

using TOML

const ROOT = normpath(joinpath(@__DIR__, ".."))
const CATALOG = joinpath(ROOT, "catalog")
const DEFAULT_LIMIT = 256 * 1024^2

function resource_sections(lines)
    starts = findall(i -> strip(lines[i]) == "[[resource]]", eachindex(lines))
    return [(first_line,
             position == length(starts) ? length(lines) : starts[position + 1] - 1)
            for (position, first_line) in enumerate(starts)]
end

function section_value(lines, range, key)
    prefix = key * " ="
    offset = findfirst(i -> startswith(strip(lines[i]), prefix), collect(range))
    offset === nothing && return nothing
    line = first(range) + offset - 1
    return TOML.parse(strip(lines[line]))[key]
end

function main(args=ARGS)
    limit = isempty(args) ? DEFAULT_LIMIT : parse(Int, args[1])
    source = joinpath(CATALOG, "satellites.toml")
    lines = readlines(source; keep=true)
    sections = resource_sections(lines)
    removed = Tuple{String,Int,Vector{String}}[]
    remove_lines = Set{Int}()
    for range in sections
        size = section_value(lines, range[1]:range[2], "size_bytes")
        size isa Integer || continue
        size > limit || continue
        id = String(section_value(lines, range[1]:range[2], "id"))
        push!(removed, (id, size, lines[range[1]:range[2]]))
        union!(remove_lines, range[1]:range[2])
    end
    if isempty(removed)
        destination = joinpath(CATALOG, "candidates", "oversized.toml")
        count = isfile(destination) ?
                length(get(TOML.parsefile(destination), "candidate", Any[])) : 0
        println("No active satellite resources exceed $limit bytes; " *
                "$count oversized candidates are already recorded.")
        return
    end

    open(source, "w") do io
        for i in eachindex(lines)
            i in remove_lines || write(io, lines[i])
        end
    end

    destination = joinpath(CATALOG, "candidates", "oversized.toml")
    mkpath(dirname(destination))
    open(destination, "w") do io
        println(io, "# Oversized authoritative resources excluded from the public catalogue.")
        println(io, "# Reconsider individually only after an explicit storage and use-case review.")
        println(io)
        println(io, "maximum_active_size_bytes = $limit")
        first_section = first(sections)[1]
        for line in lines[1:first_section-1]
            write(io, line)
        end
        println(io)
        for (_, _, block) in removed
            block[1] = replace(block[1], "[[resource]]" => "[[candidate]]")
            foreach(line -> write(io, line), block)
            println(io, "candidate_reason = \"Exceeds the 256 MiB active immutable-resource size policy.\"")
            println(io, "source_catalog = \"satellites.toml\"")
        end
    end

    println("Removed $(length(removed)) active resources larger than $limit bytes:")
    foreach(item -> println("  ", item[1], " (", item[2], " bytes)"), removed)
    println("Candidate record: ", destination)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
