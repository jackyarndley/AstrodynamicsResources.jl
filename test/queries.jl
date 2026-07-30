@testset "queries and display" begin
    @test resource_info(:de440s) === resource(:de440s)
    @test getfield.(list_resources(category=:ephemeris, format="SPICE SPK",
                                   available=false; provider=:naif), :id) ==
          [:de430, :de432s, :de435, :de438, :de440, :de440s]
    @test length(list_resources(category=:ephemeris)) == 6
    @test !isempty(find_resources("lunar principal axis"; body=:moon))
    @test any(spec -> spec.id == :jup349,
              find_resources("Jupiter satellite ephemeris"))
    @test occursin("Resource de440s", sprint(show, resource(:de440s)))
    @test resource_status(:de440s).error == "pending publication"
    @test_throws KeyError resource(:not_a_resource)
end
