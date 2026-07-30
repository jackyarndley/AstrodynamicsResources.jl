module DiscoverySupport

using Downloads
using TOML

export fetch_text, hrefs, checksum_index, catalogue_entries, write_change_report

function fetch_text(url::String)
    path = Downloads.download(url)
    try
        return read(path, String)
    finally
        rm(path; force=true)
    end
end

function hrefs(html::String)
    links = String[]
    for match in eachmatch(r"""href=["']([^"'?#]+)["']"""i, html)
        link = match.captures[1]
        (link == "../" || occursin("a_old_versions", link)) && continue
        push!(links, link)
    end
    sort!(unique!(links))
    return links
end

function checksum_index(text::String)
    checksums = Dict{String,String}()
    # NAIF indexes are either line-oriented or whitespace-only pairs.
    tokens = split(text)
    index = 1
    while index + 1 <= length(tokens)
        digest, filename = tokens[index], tokens[index + 1]
        if occursin(r"^[0-9a-fA-F]{32,64}$", digest)
            checksums[filename] = lowercase(digest)
            index += 2
        else
            index += 1
        end
    end
    return checksums
end

function catalogue_entries(path::String; table::String="resource")
    parsed = TOML.parsefile(path)
    defaults = Dict{String,Any}(get(parsed, "defaults", Dict{String,Any}()))
    return [merge(defaults, Dict{String,Any}(entry))
            for entry in get(parsed, table, Any[])]
end

function write_change_report(prefix::String; discovered::Vector{String},
                             known::Vector{String}, changed::Vector{String}=String[],
                             details::AbstractDict=Dict{String,Any}())
    additions = sort(setdiff(discovered, known))
    removals = sort(setdiff(known, discovered))
    mkpath(dirname(prefix))
    machine = Dict{String,Any}(
        "generated_at" => "deterministic-runtime-field",
        "additions" => additions,
        "removals" => removals,
        "changed" => sort(changed),
        "discovered" => sort(discovered),
        "details" => Dict{String,Any}(details),
    )
    open(prefix * ".toml", "w") do io
        TOML.print(io, machine; sorted=true)
    end
    open(prefix * ".md", "w") do io
        println(io, "# Upstream discovery report")
        println(io)
        println(io, "Generated deterministically from the authoritative index.")
        for (heading, values) in (("Additions", additions), ("Removals", removals),
                                  ("Integrity changes", sort(changed)))
            println(io)
            println(io, "## ", heading)
            println(io)
            if isempty(values)
                println(io, "None.")
            else
                foreach(value -> println(io, "- `", value, "`"), values)
            end
        end
    end
    return isempty(additions) && isempty(removals) && isempty(changed)
end

end
