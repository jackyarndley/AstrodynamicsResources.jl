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

include(joinpath(@__DIR__, "..", "scripts", "lib", "source_cache.jl"))
using .SourceCache

@testset "resumable source cache response handling" begin
    body = Vector{UInt8}(codeunits("complete immutable source bytes"))

    server = start_fixture_server(body)
    port = getsockname(server.listener)[2]
    mktempdir() do directory
        part = joinpath(directory, "source.part")
        write(part, body[1:7])
        SourceCache._download_resumable("http://127.0.0.1:$port/source", part, nothing)
        @test read(part) == body
    end
    stop_fixture_server(server)

    server = start_fixture_server(body; range_416=true)
    port = getsockname(server.listener)[2]
    mktempdir() do directory
        part = joinpath(directory, "source.part")
        write(part, body)
        SourceCache._download_resumable("http://127.0.0.1:$port/source", part, nothing)
        @test read(part) == body
    end
    stop_fixture_server(server)
end

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
                tasks = [@async only(AstrodynamicsResources._scratch_paths(spec)) for _ in 1:8]
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
