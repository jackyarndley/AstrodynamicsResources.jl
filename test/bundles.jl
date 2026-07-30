@testset "ordered bundles" begin
    @test bundle(:de440_standard).members[1] == :de440s
    @test bundle(:de440_full).members[1] == :de440
    @test bundle(:de430_standard).members[1] == :de430
    @test bundle(:de432s_standard).members[1] == :de432s
    @test bundle(:de435_standard).members[1] == :de435
    @test bundle(:de438_standard).members[1] == :de438
    @test bundle(:moon_de440_pa).members[end] == :moon_assoc_pa
    @test bundle(:moon_de440_me).members[end] == :moon_assoc_me
    @test bundle(:moon_de440_pa).members != bundle(:moon_de440_me).members
    @test_throws ArgumentError resource_path(:moon_de440_pa)
    @test AstrodynamicsResources._bundle_resource_ids(:moon_de440_orientation) ==
          [:pck00011, :moon_pa_de440, :moon_de440_frames]
    @test isempty(bundle(:earth_gravity_standard).members)
end
