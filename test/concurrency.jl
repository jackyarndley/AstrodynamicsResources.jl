@testset "concurrent scratch access" begin
    body = Vector{UInt8}(codeunits("concurrent-fixture\n"))
    server = start_fixture_server(body)
    inherited_offline = get(ENV, "ASTRODYNAMICS_RESOURCES_OFFLINE", nothing)
    try
        port = getsockname(server.listener)[2]
        spec = fixture_spec(port; id=:concurrent_fixture)
        mktempdir() do cache
            withenv("ASTRODYNAMICS_RESOURCES_CACHE" => cache,
                    "ASTRODYNAMICS_RESOURCES_OFFLINE" => "false") do
                tasks = [@async only(AstrodynamicsResources._scratch_paths(spec))
                         for _ in 1:8]
                paths = fetch.(tasks)
                @test length(unique(paths)) == 1
                @test read(only(unique(paths))) == body
                @test server.requests[] == 1
            end
        end
    finally
        stop_fixture_server(server)
    end
    @test get(ENV, "ASTRODYNAMICS_RESOURCES_OFFLINE", nothing) == inherited_offline
end
