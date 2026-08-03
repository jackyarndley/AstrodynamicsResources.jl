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
    @test bundle(:moon_de440_pa).members[end] == :moon_assoc_pa
    @test bundle(:moon_de440_me).members[end] == :moon_assoc_me
    @test bundle(:moon_de440_pa).members != bundle(:moon_de440_me).members
    @test_throws ArgumentError resource_path(:moon_de440_pa)
    @test AstrodynamicsResources._bundle_resource_ids(:moon_de440_orientation) ==
          [:pck00011, :moon_pa_de440, :moon_de440_frames]
    @test bundle(:earth_gravity_standard).members == [:ggm05c, :goco06s]
end
