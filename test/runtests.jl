using Test
using SafeTestsets

const GROUP = get(ENV, "GROUP", "All")

run_group(group::AbstractString) = GROUP in ("All", group)

if run_group("Core")
    @time @safetestset "catalogue" include("catalog.jl")
    @time @safetestset "catalogue validation" include("catalog_validation.jl")
    @time @safetestset "artifacts" include("artifacts.jl")
    @time @safetestset "scratch" include("scratch.jl")
end

if run_group("Aqua") && get(ENV, "ASTRODYNAMICS_RESOURCES_RUN_AQUA", "true") == "true"
    @time @safetestset "Aqua" include("aqua.jl")
end
