const _DOWNLOAD_SEMAPHORES = Dict{Int, Channel{Nothing}}()
const _DOWNLOAD_SEMAPHORE_LOCK = ReentrantLock()

function _download_semaphore()
    count = _max_downloads()
    return lock(_DOWNLOAD_SEMAPHORE_LOCK) do
        return get!(_DOWNLOAD_SEMAPHORES, count) do
            channel = Channel{Nothing}(count)
            foreach(_ -> put!(channel, nothing), 1:count)
            channel
        end
    end
end

function _with_download_slot(f::Function)
    semaphore = _download_semaphore()
    take!(semaphore)
    try
        return f()
    finally
        put!(semaphore, nothing)
    end
end

function _scratch_root(spec::ResourceSpec)
    custom = strip(get(ENV, "ASTRODYNAMICS_RESOURCES_CACHE", ""))
    if !isempty(custom)
        root = abspath(custom)
        mkpath(root)
        return joinpath(root, (spec.backend::ScratchBackend).key)
    end
    return Scratch.get_scratch!(@__MODULE__, (spec.backend::ScratchBackend).key)
end

_metadata_path(root::String) = joinpath(root, "metadata.toml")

function _file_sha256(path::String)
    return open(path, "r") do io
        bytes2hex(SHA.sha256(io))
    end
end

function _parse_datetime(value)
    value === nothing && return nothing
    try
        return DateTime(String(value))
    catch
        return nothing
    end
end

function _read_metadata(root::String)
    path = _metadata_path(root)
    isfile(path) || return Dict{String, Any}()
    try
        return TOML.parsefile(path)
    catch
        return Dict{String, Any}()
    end
end

function _write_metadata(root::String, metadata::Dict{String, Any})
    mkpath(root)
    temp = joinpath(root, "metadata.toml.part.$(getpid()).$(rand(UInt))")
    open(temp, "w") do io
        TOML.print(io, metadata; sorted = true)
        flush(io)
    end
    Base.Filesystem.rename(temp, _metadata_path(root))
    return nothing
end

function _header(response, name::String)
    wanted = lowercase(name)
    for (key, value) in response.headers
        lowercase(String(key)) == wanted && return String(value)
    end
    return nothing
end

function _looks_like_html(path::String)
    size = filesize(path)
    size == 0 && return false
    bytes = open(path, "r") do io
        read(io, min(size, 512))
    end
    text = lowercase(String(copy(filter(byte -> byte < 0x80, bytes))))
    return occursin("<!doctype html", text) || occursin("<html", text)
end

function _validate_download(spec::ResourceSpec, path::String, response)
    minimum = Int(get(spec.metadata, "minimum_size_bytes", 1))
    filesize(path) >= minimum || throw(
        ErrorException(
            "download for $(spec.id) is smaller than the required $minimum bytes"
        )
    )
    _looks_like_html(path) && throw(
        ErrorException(
            "download for $(spec.id) appears to be an HTML error page"
        )
    )
    expected = lowercase(String(get(spec.metadata, "expected_content_type", "")))
    actual = something(_header(response, "content-type"), "")
    if !isempty(expected) && !isempty(actual) && !occursin(expected, lowercase(actual))
        throw(
            ErrorException(
                "download for $(spec.id) has content type $actual; expected $expected"
            )
        )
    end
    return nothing
end

function _with_cache_lock(f::Function, root::String)
    mkpath(root)
    lockdir = joinpath(root, ".lock")
    deadline = time() + _timeout()
    acquired = false
    while !acquired
        try
            mkdir(lockdir)
            acquired = true
        catch error
            isdir(lockdir) || rethrow(error)
            if time() - stat(lockdir).mtime > max(600.0, 2 * _timeout())
                try
                    rm(lockdir; recursive = true)
                catch
                end
            elseif time() >= deadline
                throw(ErrorException("timed out waiting for live-resource cache lock $lockdir"))
            else
                sleep(0.05)
            end
        end
    end
    try
        return f()
    finally
        isdir(lockdir) && rm(lockdir; recursive = true)
    end
end

function _cache_file(spec::ResourceSpec, root::String)
    primary = findfirst(file -> file.primary, spec.files)
    file = primary === nothing ? first(spec.files) : spec.files[primary]
    return joinpath(root, file.path)
end

function _is_fresh(spec::ResourceSpec, metadata::Dict{String, Any}, path::String)
    isfile(path) || return false
    checked = _parse_datetime(get(metadata, "last_checked", nothing))
    checked === nothing && return false
    return now(UTC) <= checked + Second(_ttl_seconds(spec))
end

function _download_live!(spec::ResourceSpec, root::String, existing::Dict{String, Any})
    destination = _cache_file(spec, root)
    mkpath(dirname(destination))
    headers = Pair{String, String}[]
    haskey(existing, "etag") && push!(headers, "If-None-Match" => String(existing["etag"]))
    haskey(existing, "last_modified") &&
        push!(headers, "If-Modified-Since" => String(existing["last_modified"]))
    errors = String[]
    for url in _live_urls(spec)
        part = destination * ".part.$(getpid()).$(rand(UInt))"
        try
            response = Downloads.request(url; output = part, headers = headers, timeout = _timeout())
            if response.status == 304
                isfile(part) && rm(part)
                isfile(destination) || throw(ErrorException("server returned 304 without a cached file"))
                updated = copy(existing)
                updated["last_checked"] = string(now(UTC))
                updated["fresh_until"] = string(now(UTC) + Second(_ttl_seconds(spec)))
                _write_metadata(root, updated)
                return destination
            end
            200 <= response.status < 300 ||
                throw(ErrorException("HTTP status $(response.status)"))
            _validate_download(spec, part, response)
            digest = _file_sha256(part)
            # `rename` maps to an atomic same-filesystem replacement on the
            # supported platforms, including MoveFileEx semantics on Windows.
            # If it fails, the existing destination remains valid.
            Base.Filesystem.rename(part, destination)
            stamp = now(UTC)
            metadata = Dict{String, Any}(
                "resource_id" => String(spec.id),
                "source_url" => url,
                "retrieved_at" => string(stamp),
                "last_checked" => string(stamp),
                "sha256" => digest,
                "size_bytes" => filesize(destination),
                "fresh_until" => string(stamp + Second(_ttl_seconds(spec))),
            )
            for (header, key) in (
                    ("etag", "etag"), ("last-modified", "last_modified"),
                    ("content-type", "content_type"),
                )
                value = _header(response, header)
                value !== nothing && (metadata[key] = value)
            end
            _write_metadata(root, metadata)
            return destination
        catch error
            isfile(part) && rm(part; force = true)
            push!(errors, "$url: $(sprint(showerror, error))")
        end
    end
    throw(ErrorException("all sources failed for $(spec.id): " * join(errors, "; ")))
end

function _scratch_paths(
        spec::ResourceSpec; force::Bool = false,
        stale_ok::Bool = _allow_stale(),
        offline::Union{Nothing, Bool} = nothing, kwargs...
    )
    root = _scratch_root(spec)
    return _with_cache_lock(root) do
        destination = _cache_file(spec, root)
        metadata = _read_metadata(root)
        effective_offline = something(offline, _offline())
        !force && _is_fresh(spec, metadata, destination) &&
            return _paths_from_root(spec, root)
        if effective_offline
            if isfile(destination) && stale_ok
                return _paths_from_root(spec, root)
            end
            throw(
                ErrorException(
                    "resource $(spec.id) is unavailable in offline mode (backend=scratch). " *
                        "Expected one of: $(join(_live_urls(spec), ", ")). Cache it once while online " *
                        "or set ASTRODYNAMICS_RESOURCES_ALLOW_STALE=true for an existing stale cache."
                )
            )
        end
        try
            _with_download_slot() do
                _download_live!(spec, root, metadata)
            end
        catch error
            if isfile(destination) && stale_ok
                failed = copy(metadata)
                failed["last_error"] = sprint(showerror, error)
                failed["last_error_at"] = string(now(UTC))
                _write_metadata(root, failed)
                return _paths_from_root(spec, root)
            end
            rethrow(error)
        end
        return _paths_from_root(spec, root)
    end
end

"""
    refresh!(id::Symbol; force=false, kwargs...)

Revalidate a live resource. Artifact resources are immutable and are only
materialized if missing.
"""
function refresh!(id::Symbol; force::Bool = false, kwargs...)
    spec = resource(id)
    spec.backend isa ScratchBackend ||
        return resource_paths(id; kwargs...)
    return resource_paths(id; force = true, kwargs...)
end

"""
    clear_resource!(id::Symbol)

Remove only the selected live-resource cache. Immutable artifacts remain managed
by Julia's shared artifact store.
"""
function clear_resource!(id::Symbol)
    spec = resource(id)
    spec.backend isa ScratchBackend || throw(
        ArgumentError(
            "clear_resource! only removes mutable scratch caches; Julia manages immutable artifact $(spec.id)"
        )
    )
    root = abspath(_scratch_root(spec))
    isdir(root) || return false
    _with_cache_lock(root) do
        for entry in readdir(root; join = true)
            basename(entry) == ".lock" && continue
            isdir(entry) ? rm(entry; recursive = true) : rm(entry)
        end
    end
    return true
end
