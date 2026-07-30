const _TRUE_VALUES = Set(("1", "true", "yes", "on"))
const _FALSE_VALUES = Set(("0", "false", "no", "off"))

function _env_bool(name::String, default::Bool)
    raw = lowercase(strip(get(ENV, name, string(default))))
    raw in _TRUE_VALUES && return true
    raw in _FALSE_VALUES && return false
    throw(ArgumentError("$name must be one of true/false, 1/0, yes/no, or on/off"))
end

_offline() = _env_bool("ASTRODYNAMICS_RESOURCES_OFFLINE", false)
_allow_stale() = _env_bool("ASTRODYNAMICS_RESOURCES_ALLOW_STALE", true)

function _timeout()
    value = tryparse(Float64, get(ENV, "ASTRODYNAMICS_RESOURCES_TIMEOUT", "60"))
    value === nothing || value <= 0 ? 60.0 : value
end

function _max_downloads()
    value = tryparse(Int, get(ENV, "ASTRODYNAMICS_RESOURCES_MAX_DOWNLOADS", "4"))
    return value === nothing || value < 1 ? 4 : value
end

function _ttl_seconds(spec::ResourceSpec)
    name = "ASTRODYNAMICS_RESOURCES_TTL_" * uppercase(replace(String(spec.id), '-' => '_'))
    value = tryparse(Int, get(ENV, name, ""))
    return value === nothing || value < 0 ? Dates.value((spec.backend::ScratchBackend).ttl) : value
end

function _live_urls(spec::ResourceSpec)
    urls = copy((spec.backend::ScratchBackend).urls)
    mirror = strip(get(ENV, "ASTRODYNAMICS_RESOURCES_MIRROR", ""))
    if !isempty(mirror)
        filename = get(spec.metadata, "source_filename", first(spec.files).path)
        pushfirst!(urls, rstrip(mirror, '/') * "/" * filename)
    end
    unique!(urls)
    return urls
end
