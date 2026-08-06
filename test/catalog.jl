using Test
using AstrodynamicsResources

@testset "catalogue" begin
    @test validate_catalog()
    @test length(list_resources()) == 65
    @test length(list_resources(backend = :artifact)) == 53
    @test length(list_resources(backend = :scratch)) == 12
    @test all(
        spec -> spec.available == haskey(spec.metadata, "git_tree_sha1"),
        list_resources(backend = :artifact)
    )

    @test resource(:pinned_leapseconds).id == :naif0012
    @test resource(:moon_pa_de440).id == :moon_pa_de440_200625
    @test resource(:moon_de440_frames).id == :moon_de440_250416_frames
    @test resource(:hip_main).id == :hipparcos
    @test resource(:tyc2).id == :tycho2
    @test resource(:moon_pa_de440).metadata["metadata_url"] ==
        "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/moon_pa_de440_200625.cmt"
    @test resource(:hipparcos).metadata["metadata_url"] ==
        "https://cdsarc.cds.unistra.fr/ftp/I/239/ReadMe"

    @test resource(:de431_part1).metadata["source_filename"] == "de431_part-1.bsp"
    @test resource(:de431_part2).metadata["source_filename"] == "de431_part-2.bsp"
    @test resource(:de441_part1).metadata["source_filename"] == "de441_part-1.bsp"
    @test resource(:de441_part2).metadata["source_filename"] == "de441_part-2.bsp"
    @test resource(:de442).metadata["source_filename"] == "de442.bsp"
    @test resource(:ura184_part1).metadata["source_filename"] == "ura184_part-1.bsp"
    @test resource(:de440s).metadata["asset"] == "de440s.tar.gz"
    @test endswith(
        resource(:de440s).metadata["download_url"],
        "/v0.1.0/de440s.tar.gz"
    )
    @test all(
        spec -> !spec.available ||
            haskey(spec.metadata, "source_sha256") ||
            haskey(spec.metadata, "files"),
        list_resources(backend = :artifact)
    )
    @test all(
        spec -> !spec.available || haskey(spec.metadata, "archive_sha256"),
        list_resources(backend = :artifact)
    )
    @test resource(:goco06s).provider == :icgem

    @test all(spec -> haskey(spec.metadata, "license"), list_resources())
    @test all(
        spec -> startswith(String(spec.metadata["license_url"]), "https://"),
        list_resources()
    )
    @test occursin("NAIF", String(resource(:de440s).metadata["license"]))
    @test occursin("CC BY-NC", String(resource(:silso_daily_sunspots).metadata["license"]))

    @test length(list_resources(category = :satellite_ephemeris)) == 18
    @test resource(:mar099s).metadata["body"] == "Mars"
    @test length(list_resources(category = :star_catalogue)) == 3
    @test resource(:fk5).provider == :cds
    @test resource(:hipparcos).provider == :esa
    @test resource(:fk5).metadata["source_filename"] == "catalog.gz"
    @test resource(:tycho2).metadata["source_filename"] == "tyc2.dat.00.gz"
    @test length(resource(:tycho2).metadata["source_files"]) == 20
    @test length(resource(:tycho2).files) == 21
    @test count(file -> file.primary, resource(:tycho2).files) == 1
    @test all(
        spec -> spec.metadata["format"] == "CDS fixed-width catalogue",
        list_resources(category = :star_catalogue)
    )
    @test bundle(:jupiter_satellites).members == [:jup349, :jup349_nameid]
    @test bundle(:uranus_satellites).members ==
        [:ura184_part1, :ura184_part2, :ura184_part3]
    @test bundle(:neptune_satellites).members == [:nep105]
    @test !haskey(AstrodynamicsResources._ALIASES, :latest)

    @test bundle(:earth_gravity_standard).members == [:ggm05c, :goco06s]
    @test all(
        spec -> occursin("spherical-harmonic", spec.metadata["format"]),
        list_resources(category = :gravity)
    )
end

@testset "queries, display, and laziness" begin
    @test getfield.(
        list_resources(
            category = :ephemeris, format = "SPICE SPK",
            available = true; provider = :naif
        ), :id
    ) ==
        [
        :de430, :de431_part1, :de431_part2, :de432s, :de435, :de438,
        :de440, :de440s, :de441_part1, :de441_part2, :de442, :de442s,
    ]
    @test length(list_resources(category = :ephemeris)) == 12
    @test !isempty(find_resources("moon pa"; body = :moon))
    @test any(spec -> spec.id == :de442, find_resources("DE442"))
    @test occursin("Resource de440s", sprint(show, resource(:de440s)))
    @test resource_status(:de440s).backend == :artifact
    @test_throws KeyError resource(:not_a_resource)

    before = Dict(spec.id => resource_status(spec.id).available for spec in list_resources())
    resource(:de440s)
    list_resources()
    find_resources("moon")
    bundle(:moon_de440_pa)
    @test before == Dict(spec.id => resource_status(spec.id).available for spec in list_resources())
end

@testset "ordered bundles" begin
    @test bundle(:de440_standard).members[1] == :de440s
    @test bundle(:de440_full).members[1] == :de440
    @test bundle(:de430_standard).members[1] == :de430
    @test bundle(:de431).members == [:de431_part1, :de431_part2]
    @test AstrodynamicsResources._bundle_resource_ids(:de431_full)[1:2] ==
        [:de431_part1, :de431_part2]
    @test bundle(:de432s_standard).members[1] == :de432s
    @test bundle(:de435_standard).members[1] == :de435
    @test bundle(:de438_standard).members[1] == :de438
    @test bundle(:de441).members == [:de441_part1, :de441_part2]
    @test AstrodynamicsResources._bundle_resource_ids(:de441_full)[1:2] ==
        [:de441_part1, :de441_part2]
    @test bundle(:de442_standard).members[1] == :de442s
    @test bundle(:de442_full).members[1] == :de442
    @test bundle(:star_catalogues).members == [:fk5, :hipparcos, :tycho2]
    @test bundle(:moon_de440_pa).members[end] == :moon_assoc_pa
    @test bundle(:moon_de440_me).members[end] == :moon_assoc_me
    @test bundle(:moon_de440_pa).members != bundle(:moon_de440_me).members
    @test AstrodynamicsResources._bundle_resource_ids(:moon_de440_orientation) ==
        [:pck00011, :moon_pa_de440, :moon_de440_frames]
    @test bundle(:earth_gravity_standard).members == [:ggm05c, :goco06s]
    @test isdefined(AstrodynamicsResources, :resource_paths)
    @test !isdefined(AstrodynamicsResources, :resource_path)
    @test !isdefined(AstrodynamicsResources, :materialize)
end
