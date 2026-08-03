@testset "catalogue" begin
    @test validate_catalog()
    @test length(list_resources()) == 62
    @test length(list_resources(backend=:artifact)) == 50
    @test length(list_resources(backend=:scratch)) == 12
    @test all(spec -> spec.available, list_resources(backend=:artifact))

    @test resource(:pinned_leapseconds).id == :naif0012
    @test resource(:moon_pa_de440).id == :moon_pa_de440_200625
    @test resource(:moon_de440_frames).id == :moon_de440_250416_frames
    @test resource(:moon_pa_de440).metadata["metadata_url"] ==
          "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/moon_pa_de440_200625.cmt"

    @test resource(:de431_part1).metadata["source_filename"] == "de431_part-1.bsp"
    @test resource(:de431_part2).metadata["source_filename"] == "de431_part-2.bsp"
    @test resource(:de441_part1).metadata["source_filename"] == "de441_part-1.bsp"
    @test resource(:de441_part2).metadata["source_filename"] == "de441_part-2.bsp"
    @test resource(:de442).metadata["source_filename"] == "de442.bsp"
    @test resource(:ura184_part1).metadata["source_filename"] == "ura184_part-1.bsp"
    @test resource(:de440s).metadata["asset"] == "de440s.tar.gz"
    @test endswith(resource(:de440s).metadata["download_url"],
                   "/v0.1.0/de440s.tar.gz")
    @test all(spec -> haskey(spec.metadata, "source_sha256"),
              list_resources(backend=:artifact))
    @test all(spec -> haskey(spec.metadata, "archive_sha256"),
              list_resources(backend=:artifact))

    @test length(list_resources(category=:satellite_ephemeris)) == 18
    @test resource(:mar099s).metadata["body"] == "Mars"
    @test bundle(:jupiter_satellites).members == [:jup349, :jup349_nameid]
    @test bundle(:uranus_satellites).members ==
          [:ura184_part1, :ura184_part2, :ura184_part3]
    @test bundle(:neptune_satellites).members == [:nep105]
    @test !haskey(AstrodynamicsResources._ALIASES, :latest)

    @test bundle(:earth_gravity_standard).members == [:ggm05c, :goco06s]
    @test all(spec -> occursin("spherical-harmonic", spec.metadata["format"]),
              list_resources(category=:gravity))
end
