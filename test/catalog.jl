@testset "catalogue" begin
    @test validate_catalog()
    @test length(list_resources()) >= 51
    @test resource(:pinned_leapseconds).id == :naif0012
    @test resource(:moon_pa_de440).id == :moon_pa_de440_200625
    @test resource(:moon_de440_frames).metadata["frame_ids"] == [31000, 31001, 31008, 31009]
    @test isempty(filter(spec -> occursin("de441", String(spec.id)), list_resources()))
    @test isempty(filter(spec -> occursin("de431", String(spec.id)), list_resources()))
    @test all(id -> resource(id).metadata["source_filename"] ==
                    Dict(:de430 => "de430.bsp",
                         :de432s => "de432s.bsp",
                         :de435 => "de435.bsp",
                         :de438 => "de438.bsp",
                         :de442s => "de442s.bsp",
                         :de442 => "de442.bsp")[id],
              (:de430, :de432s, :de435, :de438, :de442s, :de442))
    @test all(spec -> spec.backend isa ArtifactBackend,
              list_resources(backend=:artifact))
    @test all(spec -> spec.metadata["redistribution"] == "permitted",
              list_resources(backend=:artifact))
    @test all(spec -> spec.metadata["redistribution_url"] ==
                      "https://naif.jpl.nasa.gov/naif/rules.html",
              list_resources(backend=:artifact))
    @test all(spec -> haskey(spec.metadata, "source_sha256"),
              list_resources(backend=:artifact))
    @test all(spec -> !spec.available, list_resources(backend=:artifact))
    @test all(spec -> spec.backend isa ScratchBackend,
              list_resources(backend=:scratch))

    ids = getfield.(list_resources(category=:satellite_ephemeris), :id)
    @test length(ids) == 18
    @test all(spec -> spec.metadata["object_class"] == "natural satellites",
              list_resources(category=:satellite_ephemeris))
    @test_throws KeyError resource(:mar099s)
    @test resource(:ura184_part1).metadata["source_filename"] == "ura184_part-1.bsp"
    @test bundle(:jupiter_satellites).members == [:jup349, :jup349_nameid]
    @test bundle(:uranus_satellites).members ==
          [:ura184_part1, :ura184_part2, :ura184_part3]
    @test bundle(:neptune_satellites).members == [:nep105]
    @test !haskey(AstrodynamicsResources._ALIASES, :latest)
end
