using Test
using AstrodynamicsResources

include("catalog.jl")
include("catalog_validation.jl")
include("artifacts.jl")
include("scratch.jl")

if get(ENV, "ASTRODYNAMICS_RESOURCES_RUN_AQUA", "true") == "true"
    using Aqua
    Aqua.test_all(AstrodynamicsResources; ambiguities=false)
end
