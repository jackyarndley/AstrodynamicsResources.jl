@testset "offline mode" begin
    body = Vector{UInt8}(codeunits("offline-fixture\n"))
    server = start_fixture_server(body)
    port = getsockname(server.listener)[2]
    spec = fixture_spec(port; id=:offline_fixture)
    mktempdir() do cache
        withenv("ASTRODYNAMICS_RESOURCES_CACHE" => cache) do
            @test_throws ErrorException AstrodynamicsResources._scratch_paths(
                spec; offline=true, stale_ok=true)
            @test server.requests[] == 0
            path = only(AstrodynamicsResources._scratch_paths(spec; offline=false))
            requests = server.requests[]
            @test only(AstrodynamicsResources._scratch_paths(
                spec; offline=true, force=true, stale_ok=true)) == path
            @test server.requests[] == requests
            @test_throws ErrorException AstrodynamicsResources._scratch_paths(
                spec; offline=true, force=true, stale_ok=false)
        end
    end
    stop_fixture_server(server)
end
