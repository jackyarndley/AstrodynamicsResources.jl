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
    @test_throws ErrorException resource_path(:de440s)
end
