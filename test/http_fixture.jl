using Sockets
using Dates

mutable struct FixtureServer
    listener::Sockets.TCPServer
    task::Task
    requests::Base.RefValue{Int}
    fail::Base.RefValue{Bool}
end

function start_fixture_server(body::Vector{UInt8})
    listener = listen(ip"127.0.0.1", 0)
    requests = Ref(0)
    fail = Ref(false)
    task = @async begin
        while isopen(listener)
            socket = try
                accept(listener)
            catch
                break
            end
            try
                requests[] += 1
                headers = String[]
                while true
                    line = readline(socket; keep=true)
                    isempty(strip(line)) && break
                    push!(headers, line)
                end
                conditional = any(line -> occursin("If-None-Match", line), headers)
                if fail[]
                    write(socket, "HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
                elseif conditional
                    write(socket, "HTTP/1.1 304 Not Modified\r\nETag: \"fixture-v1\"\r\nConnection: close\r\n\r\n")
                else
                    write(socket, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nETag: \"fixture-v1\"\r\nContent-Length: $(length(body))\r\nConnection: close\r\n\r\n")
                    write(socket, body)
                end
                flush(socket)
            finally
                close(socket)
            end
        end
    end
    return FixtureServer(listener, task, requests, fail)
end

function stop_fixture_server(server::FixtureServer)
    close(server.listener)
    wait(server.task)
    return nothing
end

function fixture_spec(port::Integer; ttl::Int=3600, id::Symbol=:fixture_live)
    return ResourceSpec(
        id, Symbol[], "Live fixture", "Local test data", :fixture, :tests,
        "rolling",
        ScratchBackend(String(id), ["http://127.0.0.1:$port/data.txt"], Second(ttl)),
        [ResourceFile("data.txt", :data, true)],
        Dict{String,Any}(
            "format" => "text",
            "minimum_size_bytes" => 4,
            "source_filename" => "data.txt",
        ),
        true,
    )
end
