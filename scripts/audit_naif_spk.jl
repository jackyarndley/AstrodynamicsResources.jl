#!/usr/bin/env julia

"""Compare the active NAIF generic SPK tree with the hand-maintained catalog.

This is a maintainer tool. It reads directory indexes over HTTPS, skips known
archive directories, and reports differences without changing any repository
file. It is deliberately not called from package import or the normal tests.
"""

using Downloads
using TOML

const ROOT = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/"
const ARCHIVE_NAMES = Set(("a_old_versions", "old_versions", "archive", "archives"))

function fetch_text(url::AbstractString)
    path = Downloads.download(url)
    try
        return read(path, String)
    finally
        rm(path; force = true)
    end
end

function child_url(parent::AbstractString, href::AbstractString)
    occursin("://", href) && return String(href)
    startswith(href, "/") && return "https://naif.jpl.nasa.gov$href"
    return string(parent, href)
end

function archive_path(relative::AbstractString)
    return any(segment -> lowercase(segment) in ARCHIVE_NAMES, split(relative, '/'))
end

function crawl!(url::String, root::String, seen::Set{String}, files::Set{String}, ignored::Set{String})
    url in seen && return
    push!(seen, url)
    html = fetch_text(url)
    for match in eachmatch(r"href=\"([^\"]+)\"", html)
        href = match.captures[1]
        if isempty(href) || href in ("../", "./") || startswith(href, "?") ||
                startswith(href, "#")
            continue
        end
        current = child_url(url, href)
        startswith(current, root) || continue
        relative = current[(length(root) + 1):end]
        if archive_path(relative)
            endswith(href, '/') && push!(ignored, relative)
            continue
        end
        if endswith(href, '/')
            crawl!(current, root, seen, files, ignored)
        elseif endswith(lowercase(href), ".bsp")
            push!(files, current)
        end
    end
    return
end

function catalog_urls(path::AbstractString)
    parsed = TOML.parsefile(path)
    urls = Set{String}()
    for raw in get(parsed, "resource", Any[])
        entry = Dict{String, Any}(raw)
        sources = haskey(entry, "url") ? [entry["url"]] :
            [file["url"] for file in get(entry, "files", Any[])]
        for url in sources
            endswith(lowercase(String(url)), ".bsp") && push!(urls, String(url))
        end
    end
    return urls
end

function print_group(title::AbstractString, values)
    println(title)
    for value in sort!(collect(values))
        println("  ", value)
    end
    return isempty(values) && println("  (none)")
end

function main()
    root = get(ENV, "NAIF_SPK_ROOT", ROOT)
    endswith(root, '/') || (root *= '/')
    catalog = joinpath(normpath(joinpath(@__DIR__, "..")), "catalog", "Resources.toml")
    upstream = Set{String}()
    ignored = Set{String}()
    crawl!(root, root, Set{String}(), upstream, ignored)
    catalogued = catalog_urls(catalog)
    print_group("NEW UPSTREAM", setdiff(upstream, catalogued))
    print_group("CATALOGUED", intersect(upstream, catalogued))
    print_group(
        "NO LONGER ACTIVE",
        filter(url -> startswith(url, root), setdiff(catalogued, upstream)),
    )
    print_group("IGNORED", ignored)
    return nothing
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
