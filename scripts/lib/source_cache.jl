module SourceCache

using Downloads
using SHA
using TOML

export fetch_verified_source, file_sha256

file_sha256(path::AbstractString) = open(path, "r") do io
    bytes2hex(SHA.sha256(io))
end

function reject_bad_source(
        path::AbstractString, source_filename::AbstractString;
        expected_size::Union{Nothing, Integer} = nothing
    )
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

_retryable_status(status::Integer) =
    status in (202, 408, 425, 429, 500, 502, 503, 504) || 500 <= status < 600

_backoff(attempt::Integer) = min(2.0^(attempt - 1), 60.0)

function _download_resumable(
        url::String, part::String,
        expected_size::Union{Nothing, Integer}
    )
    attempt = 1
    max_attempts = parse(Int, get(ENV, "ASTRODYNAMICS_RESOURCES_DOWNLOAD_ATTEMPTS", "8"))
    max_attempts >= 1 || error("ASTRODYNAMICS_RESOURCES_DOWNLOAD_ATTEMPTS must be positive")
    while true
        offset = isfile(part) ? filesize(part) : 0
        if expected_size !== nothing && offset > expected_size
            rm(part; force = true)
            offset = 0
        elseif expected_size !== nothing && offset == expected_size
            return part
        end

        headers = offset > 0 ? ["Range" => "bytes=$(offset)-"] : Pair{String, String}[]
        timeout = parse(Float64, get(ENV, "ASTRODYNAMICS_RESOURCES_TIMEOUT", "60"))
        mode = offset > 0 ? "a" : "w"
        response = try
            open(part, mode) do io
                Downloads.request(url; headers = headers, output = io, timeout)
            end
        catch exception
            attempt == max_attempts && rethrow(exception)
            sleep(_backoff(attempt))
            attempt += 1
            continue
        end
        status = response.status
        if offset > 0 && status == 416
            open(part, "r+") do io
                truncate(io, offset)
            end
            return part
        end
        if offset > 0 && status == 200
            replacement = part * ".complete"
            open(part, "r") do source
                seek(source, offset)
                open(replacement, "w") do destination
                    write(destination, source)
                end
            end
            mv(replacement, part; force = true)
            return part
        elseif offset > 0 && status == 206
            return part
        elseif offset == 0 && status == 200
            return part
        end
        if offset > 0
            open(part, "r+") do io
                truncate(io, offset)
            end
        else
            rm(part; force = true)
        end
        _retryable_status(status) || error("HTTP $status while downloading $url")
        attempt == max_attempts && error("HTTP $status while downloading $url after $max_attempts attempts")
        sleep(_backoff(attempt))
        attempt += 1
    end
end

"""
    fetch_verified_source(metadata; cache_root, require_sha256=true)

Fetch an upstream file into a persistent, resumable source cache. The generated
lock SHA-256 is verified when present. Successful files
are stored under their content digest, so subsequent package releases reuse the
same immutable bytes.
"""
function fetch_verified_source(
        metadata::AbstractDict;
        cache_root::AbstractString,
        require_sha256::Bool = true,
        verify_size::Bool = true
    )
    url = String(metadata["source_url"])
    filename = String(metadata["source_filename"])
    expected_size = verify_size && haskey(metadata, "size_bytes") ?
        Int(metadata["size_bytes"]) : nothing
    expected_sha = get(metadata, "source_sha256", nothing)
    require_sha256 && expected_sha === nothing &&
        error("$filename has no independently reviewed source_sha256")

    mkpath(cache_root)
    reference = joinpath(
        cache_root, "refs",
        bytes2hex(SHA.sha256(codeunits(url))) * ".toml"
    )
    if expected_sha === nothing && isfile(reference)
        cached_metadata = TOML.parsefile(reference)
        digest = String(cached_metadata["source_sha256"])
        cached = joinpath(cache_root, digest, filename)
        if isfile(cached)
            reject_bad_source(cached, filename; expected_size)
            file_sha256(cached) == digest ||
                error("referenced cache SHA-256 mismatch for $filename")
            return cached
        end
    end
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

    digest = file_sha256(part)
    expected_sha === nothing || digest == lowercase(String(expected_sha)) ||
        error("SHA-256 mismatch for $filename: expected $expected_sha, got $digest")
    destination_dir = joinpath(cache_root, digest)
    destination = joinpath(destination_dir, filename)
    mkpath(destination_dir)
    if isfile(destination)
        file_sha256(destination) == digest ||
            error("digest cache collision at $destination")
        rm(part; force = true)
    else
        mv(part, destination)
    end
    mkpath(dirname(reference))
    temporary_reference = reference * ".tmp.$(getpid())"
    open(temporary_reference, "w") do io
        TOML.print(
            io, Dict(
                "source_filename" => filename,
                "source_sha256" => digest,
                "source_url" => url,
                "size_bytes" => filesize(destination),
            ); sorted = true
        )
    end
    mv(temporary_reference, reference; force = true)
    return destination
end

end
