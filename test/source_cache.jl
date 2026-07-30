include(joinpath(@__DIR__, "..", "scripts", "lib", "source_cache.jl"))
using .SourceCache

@testset "resumable source cache response handling" begin
    body = Vector{UInt8}(codeunits("complete immutable source bytes"))

    server = start_fixture_server(body)
    port = getsockname(server.listener)[2]
    mktempdir() do directory
        part = joinpath(directory, "source.part")
        write(part, body[1:7])
        SourceCache._download_resumable(
            "http://127.0.0.1:$port/source", part, nothing)
        @test read(part) == body
    end
    stop_fixture_server(server)

    server = start_fixture_server(body; range_416=true)
    port = getsockname(server.listener)[2]
    mktempdir() do directory
        part = joinpath(directory, "source.part")
        write(part, body)
        SourceCache._download_resumable(
            "http://127.0.0.1:$port/source", part, nothing)
        @test read(part) == body
    end
    stop_fixture_server(server)
end
