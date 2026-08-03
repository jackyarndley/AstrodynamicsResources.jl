@testset "catalogue operations are lazy" begin
    before = Dict(spec.id => resource_status(spec.id).available
                  for spec in list_resources())
    resource(:de440s)
    list_resources()
    find_resources("moon")
    bundle(:moon_de440_pa)
    after = Dict(spec.id => resource_status(spec.id).available
                 for spec in list_resources())
    @test before == after
    @test resource_status(:de440s).available == before[:de440s]
end
