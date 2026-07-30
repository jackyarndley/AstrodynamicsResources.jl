using Test
using AstrodynamicsResources

include("catalog.jl")
include("catalog_validation.jl")
include("queries.jl")
include("lazy.jl")
include("artifacts.jl")
include("scratch.jl")
include("source_cache.jl")
include("offline.jl")
include("concurrency.jl")
include("bundles.jl")
include("verification.jl")

if get(ENV, "ASTRODYNAMICS_RESOURCES_RUN_AQUA", "true") == "true"
    using Aqua
    Aqua.test_all(AstrodynamicsResources; ambiguities=false)
end
