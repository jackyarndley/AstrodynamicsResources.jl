include("http_fixture.jl")

@testset "scratch download, TTL, conditional request, and stale fallback" begin
    body = Vector{UInt8}(codeunits("fixture-live-data\n"))
    server = start_fixture_server(body)
    port = getsockname(server.listener)[2]
    spec = fixture_spec(port)
    mktempdir() do cache
        withenv("ASTRODYNAMICS_RESOURCES_CACHE" => cache,
                "ASTRODYNAMICS_RESOURCES_OFFLINE" => "false") do
            path = only(AstrodynamicsResources._scratch_paths(spec))
            @test read(path) == body
            @test server.requests[] == 1
            @test only(AstrodynamicsResources._scratch_paths(spec)) == path
            @test server.requests[] == 1

            @test only(AstrodynamicsResources._scratch_paths(spec; force=true)) == path
            @test server.requests[] == 2
            metadata = AstrodynamicsResources._read_metadata(dirname(path))
            @test metadata["etag"] == "\"fixture-v1\""
            @test metadata["sha256"] == AstrodynamicsResources._file_sha256(path)

            server.fail[] = true
            @test only(AstrodynamicsResources._scratch_paths(
                spec; force=true, stale_ok=true)) == path
            @test read(path) == body
            @test AstrodynamicsResources._scratch_status(spec).error !== nothing
            @test_throws ErrorException AstrodynamicsResources._scratch_paths(
                spec; force=true, stale_ok=false)
        end
    end
    stop_fixture_server(server)
end
