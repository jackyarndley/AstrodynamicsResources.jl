@testset "verification and status" begin
    @test !verify_resource(:de440s)
    @test !resource_status(:iers_finals2000a).available
    @test resource_status(:iers_finals2000a).backend == :scratch
    @test_throws ArgumentError clear_resource!(:de440s)
end
