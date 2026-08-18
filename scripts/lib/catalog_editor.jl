module CatalogEditor

using TOML

export catalogue_paths, update_reports!

const _GENERATED_RESOURCE_KEYS = Set((
    "sha256", "size_bytes", "artifact_sha256", "artifact_size_bytes",
    "git_tree_sha1", "metadata_sha256",
))
const _GENERATED_FILE_KEYS = Set(("sha256", "size_bytes"))

function catalogue_paths(root::AbstractString)
    directory = joinpath(root, "catalog")
    primary = joinpath(directory, "Resources.toml")
    extras = sort!(
        filter(
            path -> endswith(lowercase(path), ".toml") &&
                !(basename(path) in ("Resources.toml", "ResourceLock.toml", "bundles.toml")),
            readdir(directory; join = true),
        )
    )
    return [primary; extras]
end

function _split_catalogue(lines::Vector{String})
    preamble = String[]
    blocks = Vector{Vector{String}}()
    current = nothing
    for line in lines
        if strip(line) == "[[resource]]"
            current === nothing || push!(blocks, current)
            current = String[line]
        elseif current === nothing
            push!(preamble, line)
        else
            push!(current, line)
        end
    end
    current === nothing || push!(blocks, current)
    return preamble, blocks
end

function _resource_name(block::Vector{String})
    for line in block
        strip(line) == "[[resource.files]]" && break
        match_result = match(r"^\s*name\s*=\s*\"([^\"]+)\"", line)
        match_result === nothing || return String(match_result.captures[1])
    end
    return nothing
end

function _field_key(line::String)
    result = match(r"^\s*([A-Za-z0-9_]+)\s*=", line)
    return result === nothing ? nothing : String(result.captures[1])
end

function _strip_generated(block::Vector{String})
    result = String[]
    mode = :resource
    for line in block
        stripped = strip(line)
        stripped == "[[resource.files]]" && (mode = :file)
        key = _field_key(line)
        if key !== nothing
            mode == :resource && key in _GENERATED_RESOURCE_KEYS && continue
            mode == :file && key in _GENERATED_FILE_KEYS && continue
        end
        push!(result, line)
    end
    return result
end

_line(key, value::AbstractString) = "$key = $(repr(String(value)))\n"
_line(key, value::Integer) = "$key = $value\n"

function _report_resource_fields(report::Dict{String, Any})
    fields = String[
        _line("artifact_sha256", report["archive_sha256"]),
        _line("git_tree_sha1", report["git_tree_sha1"]),
    ]
    haskey(report, "archive_size_bytes") &&
        insert!(fields, 2, _line("artifact_size_bytes", Int(report["archive_size_bytes"])))
    if !haskey(report, "files")
        push!(fields, _line("sha256", report["source_sha256"]))
        haskey(report, "source_size_bytes") &&
            push!(fields, _line("size_bytes", Int(report["source_size_bytes"])))
    end
    haskey(report, "metadata_sha256") &&
        push!(fields, _line("metadata_sha256", report["metadata_sha256"]))
    return fields
end

function _insert_resource_fields(block::Vector{String}, report::Dict{String, Any})
    fields = _report_resource_fields(report)
    index = findfirst(line -> match(r"^\s*name\s*=", line) !== nothing, block)
    index === nothing && error("resource block has no name")
    return [block[1:index]; fields; block[(index + 1):end]]
end

function _report_files(report::Dict{String, Any})
    return Dict(
        String(file["url"]) => Dict{String, Any}(file)
        for file in get(report, "files", Any[])
    )
end

function _insert_file_fields(block::Vector{String}, report::Dict{String, Any})
    files = _report_files(report)
    isempty(files) && return block
    result = String[]
    in_file = false
    matched = Set{String}()
    for line in block
        stripped = strip(line)
        if stripped == "[[resource.files]]"
            in_file = true
            push!(result, line)
            continue
        elseif startswith(stripped, "[") && stripped != "[[resource.files]]"
            in_file = false
        end
        push!(result, line)
        if in_file
            url_match = match(r"^\s*url\s*=\s*\"([^\"]+)\"", line)
            if url_match !== nothing
                url = String(url_match.captures[1])
                haskey(files, url) || error("report contains no hash for declared file $url")
                file = files[url]
                push!(result, _line("sha256", file["sha256"]))
                haskey(file, "size_bytes") &&
                    push!(result, _line("size_bytes", Int(file["size_bytes"])))
                push!(matched, url)
            end
        end
    end
    matched == Set(keys(files)) ||
        error("report file set does not match the resource declaration")
    return result
end

function _declared_source(entry::Dict{String, Any})
    if haskey(entry, "url")
        return [Dict{String, Any}("url" => String(entry["url"]))]
    end
    return [Dict{String, Any}("url" => String(file["url"])) for file in entry["files"]]
end

function _validate_report(block::Vector{String}, report::Dict{String, Any})
    parsed = TOML.parse(join(block))
    entry = Dict{String, Any}(only(parsed["resource"]))
    String(entry["name"]) == String(report["name"]) ||
        error("report name does not match declaration")
    declared = String[file["url"] for file in _declared_source(entry)]
    reported = if haskey(report, "files")
        String[String(file["url"]) for file in report["files"]]
    else
        [String(report["source_url"])]
    end
    declared == reported ||
        error("report source URLs do not match declaration for $(report["name"])")
    metadata_url = get(entry, "metadata_url", nothing)
    report_metadata = get(report, "metadata_url", nothing)
    metadata_url == report_metadata ||
        error("report metadata URL does not match declaration for $(report["name"])")
    return nothing
end

function _update_block(block::Vector{String}, report::Dict{String, Any})
    _validate_report(block, report)
    clean = _strip_generated(block)
    with_resource = _insert_resource_fields(clean, report)
    return _insert_file_fields(with_resource, report)
end

function update_reports!(root::AbstractString, reports::Vector{Dict{String, Any}})
    by_name = Dict(String(report["name"]) => report for report in reports)
    touched = Set{String}()
    changed = String[]
    for path in catalogue_paths(root)
        lines = readlines(path; keep = true)
        preamble, blocks = _split_catalogue(lines)
        isempty(blocks) && continue
        output = copy(preamble)
        file_changed = false
        for block in blocks
            name = _resource_name(block)
            if name !== nothing && haskey(by_name, name)
                updated = _update_block(block, by_name[name])
                append!(output, updated)
                push!(touched, name)
                file_changed |= updated != block
            else
                append!(output, block)
            end
        end
        if file_changed
            write(path, join(output))
            push!(changed, path)
        end
    end
    missing = sort!(collect(setdiff(Set(keys(by_name)), touched)))
    isempty(missing) || error("resource declarations not found: $(join(missing, ", "))")
    return changed
end

end
