module SourceCache

using Downloads
using MD5
using SHA
using TOML

export fetch_verified_source, file_md5, file_sha256

file_sha256(path::AbstractString) = open(path, "r") do io
    bytes2hex(SHA.sha256(io))
end

file_md5(path::AbstractString) = open(path, "r") do io
    bytes2hex(MD5.md5(io))
end

function reject_bad_source(path::AbstractString, source_filename::AbstractString;
                           expected_size::Union{Nothing,Integer}=nothing)
    size = filesize(path)
    size > 0 || error("upstream returned an empty file")
    expected_size === nothing || size == expected_size ||
        error("size mismatch for $source_filename: expected $expected_size bytes, got $size")
    head = open(path, "r") do io
        read(io, min(size, 512))
    end
    ascii = lowercase(String(copy(filter(byte -> byte < 0x80, head))))
    (occursin("<html", ascii) || occursin("<!doctype html", ascii)) &&
        error("upstream returned an HTML page instead of $source_filename")
    return nothing
end

function _download_resumable(url::String, part::String,
                             expected_size::Union{Nothing,Integer})
    while true
        offset = isfile(part) ? filesize(part) : 0
        if expected_size !== nothing && offset > expected_size
            rm(part; force=true)
            offset = 0
        elseif expected_size !== nothing && offset == expected_size
            return part
        end

        headers = offset > 0 ? ["Range" => "bytes=$(offset)-"] : Pair{String,String}[]
        mode = offset > 0 ? "a" : "w"
        response = open(part, mode) do io
            Downloads.request(url; headers=headers, output=io)
        end
        status = response.status
        offset > 0 && status == 416 && return part
        if offset > 0 && status == 200
            # The server ignored Range and appended a full response. Retry cleanly.
            rm(part; force=true)
            continue
        end
        status in (200, 206) || error("HTTP $status while downloading $url")
        return part
    end
end

"""
    fetch_verified_source(metadata; cache_root, require_sha256=true)

Fetch an upstream file into a persistent, resumable source cache. Provider
checksums and the catalogue SHA-256 are verified when present. Successful files
are stored under their content digest, so subsequent package releases reuse the
same immutable bytes.
"""
function fetch_verified_source(metadata::AbstractDict;
                               cache_root::AbstractString,
                               require_sha256::Bool=true,
                               verify_size::Bool=true)
    url = String(metadata["source_url"])
    filename = String(metadata["source_filename"])
    expected_size = verify_size && haskey(metadata, "size_bytes") ?
                    Int(metadata["size_bytes"]) : nothing
    expected_sha = get(metadata, "source_sha256", nothing)
    require_sha256 && expected_sha === nothing &&
        error("$filename has no independently reviewed source_sha256")

    mkpath(cache_root)
    if expected_sha !== nothing
        cached = joinpath(cache_root, lowercase(String(expected_sha)), filename)
        if isfile(cached)
            reject_bad_source(cached, filename; expected_size)
            file_sha256(cached) == lowercase(String(expected_sha)) ||
                error("cached SHA-256 mismatch for $filename")
            return cached
        end
    end

    incoming = joinpath(cache_root, "incoming")
    mkpath(incoming)
    part = joinpath(incoming, filename * ".part")
    _download_resumable(url, part, expected_size)
    reject_bad_source(part, filename; expected_size)

    algorithm = lowercase(String(get(metadata, "upstream_checksum_algorithm", "")))
    provider_checksum = get(metadata, "upstream_checksum", nothing)
    if provider_checksum !== nothing
        actual = algorithm == "md5" ? file_md5(part) :
                 algorithm == "sha256" ? file_sha256(part) :
                 error("unsupported upstream checksum algorithm $algorithm")
        actual == lowercase(String(provider_checksum)) ||
            error("provider $algorithm checksum mismatch for $filename")
    end

    digest = file_sha256(part)
    expected_sha === nothing || digest == lowercase(String(expected_sha)) ||
        error("SHA-256 mismatch for $filename: expected $expected_sha, got $digest")
    destination_dir = joinpath(cache_root, digest)
    destination = joinpath(destination_dir, filename)
    mkpath(destination_dir)
    if isfile(destination)
        file_sha256(destination) == digest ||
            error("digest cache collision at $destination")
        rm(part; force=true)
    else
        mv(part, destination)
    end
    return destination
end

end
