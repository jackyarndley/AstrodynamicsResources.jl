using Test
using AstrodynamicsResources

@testset "planet textures" begin
    textures = list_resources(category = :texture)
    @test length(textures) == 20
    @test all(spec -> spec.provider == :solarsystemscope, textures)
    @test all(spec -> spec.backend isa ArtifactBackend, textures)
    @test all(spec -> spec.metadata["license"] == "CC BY 4.0; attribution to Solar System Scope required", textures)
    @test resource(:texture_earth_day).metadata["source_filename"] == "2k_earth_daymap.jpg"
    @test resource(:texture_saturn_ring).metadata["format"] == "PNG image"
    @test only(resource(:texture_saturn_ring).files).role == :texture
    @test occursin("fictional", String(resource(:texture_ceres_fictional).metadata["description"]))
    @test length(bundle(:planet_textures).members) == 20
    @test bundle(:planet_textures).members[1:4] == [
        :texture_sun, :texture_mercury, :texture_venus_surface, :texture_venus_atmosphere,
    ]
end
