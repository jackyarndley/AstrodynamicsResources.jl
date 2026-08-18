using Test
using AstrodynamicsResources

function audit_command(path::String; strict::Bool = false)
    root = normpath(joinpath(@__DIR__, ".."))
    script = joinpath(root, "scripts", "release_audit.jl")
    command = `$(Base.julia_cmd()) --project=$root $script $path`
    return strict ? `$command --strict` : command
end

function write_available_assets(path::String; omit::Union{Nothing, Symbol} = nothing)
    open(path, "w") do io
        for spec in list_resources(backend = :artifact)
            spec.available || continue
            spec.id == omit && continue
            println(
                io,
                AstrodynamicsResources.release_tag(spec), '\t',
                AstrodynamicsResources.resource_asset(spec),
            )
        end
    end
    return path
end

@testset "release audit repair and strict modes" begin
    available = filter(spec -> spec.available, list_resources(backend = :artifact))
    @test !isempty(available)

    mktempdir() do directory
        complete = write_available_assets(joinpath(directory, "complete.txt"))
        output = read(audit_command(complete), String)
        @test occursin("restore canonical copies: ", output)
        @test success(run(pipeline(audit_command(complete; strict = true); stdout = devnull)))

        missing_id = first(available).id
        incomplete = write_available_assets(
            joinpath(directory, "incomplete.txt"); omit = missing_id,
        )
        output = read(audit_command(incomplete), String)
        @test occursin("restore canonical copies: $(missing_id)", output)

        process = run(
            pipeline(ignorestatus(audit_command(incomplete; strict = true));
                stdout = devnull, stderr = devnull),
        )
        @test !success(process)
    end
end
