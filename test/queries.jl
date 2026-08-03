@testset "queries and display" begin
    @test resource_info(:de440s) === resource(:de440s)
    @test getfield.(list_resources(category=:ephemeris, format="SPICE SPK",
                                   available=true; provider=:naif), :id) ==
          [:de430, :de432s, :de435, :de438, :de440, :de440s, :de442, :de442s]
    @test length(list_resources(category=:ephemeris)) == 8
    @test !isempty(find_resources("moon pa"; body=:moon))
    @test any(spec -> spec.id == :de442,
              find_resources("DE442"))
    @test occursin("Resource de440s", sprint(show, resource(:de440s)))
    @test resource_status(:de440s).backend == :artifact
    @test_throws KeyError resource(:not_a_resource)
end
