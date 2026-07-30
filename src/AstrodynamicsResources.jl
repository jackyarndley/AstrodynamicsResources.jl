module AstrodynamicsResources

using Artifacts
using Dates
using Downloads
using LazyArtifacts
import Pkg
using SHA
using Scratch
using TOML

export AbstractResourceBackend, ArtifactBackend, ScratchBackend
export ResourceFile, ResourceSpec, ResourceBundle, ResourceStatus
export resource, resource_info, list_resources, find_resources, bundle
export resource_path, resource_paths, materialize
export resource_status, refresh!, clear_resource!, verify_resource
export validate_catalog

include("types.jl")
include("preferences.jl")
include("catalog.jl")
include("queries.jl")
include("artifacts.jl")
include("scratch.jl")
include("bundles.jl")
include("status.jl")
include("verification.jl")

function __init__()
    _load_catalog!()
    return nothing
end

end
