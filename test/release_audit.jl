using Test
using AstrodynamicsResources

function audit_command(path::String)
    root = normpath(joinpath(@__DIR__, ".."))
    script = joinpath(root, "scripts", "release_audit.jl")
    return `$(Base.julia_cmd()) --project=$root $script $path`
end

function write_assets(path::String, specs)
    open(path, "w") do io
        for spec in specs
            println(
                io,
                AstrodynamicsResources.release_tag(spec), '\t',
                AstrodynamicsResources.resource_asset(spec),
            )
        end
    end
    return path
end

@testset "release audit classification" begin
    specs = list_resources(backend = :artifact)
    available = filter(spec -> spec.available, specs)
    unavailable = filter(spec -> !spec.available, specs)
    @test !isempty(available)
    @test !isempty(unavailable)

    mktempdir() do directory
        # All committed hashes have corresponding canonical assets. Unpublished
        # resources are correctly classified as build candidates.
        complete = write_assets(joinpath(directory, "complete.txt"), available)
        output = read(audit_command(complete), String)
        @test occursin("published canonical assets: $(length(available))", output)
        @test occursin("adopt existing archives: ", output)
        @test success(run(pipeline(audit_command(complete); stdout = devnull)))

        # If an unhashed resource already has an archive, it must be adopted,
        # never rebuilt.
        existing_unhashed = first(unavailable)
        adopt_inventory = write_assets(
            joinpath(directory, "adopt.txt"), [available; existing_unhashed],
        )
        output = read(audit_command(adopt_inventory), String)
        @test occursin("adopt existing archives: $(existing_unhashed.id)", output)
        build_line = only(filter(line -> startswith(line, "build missing archives:"), split(output, '\n')))
        @test !occursin(String(existing_unhashed.id), build_line)

        # A resource with committed hashes but no canonical archive is an
        # integrity error. Do not silently rebuild or copy it from elsewhere.
        missing_hashed = first(available)
        incomplete = write_assets(
            joinpath(directory, "incomplete.txt"),
            filter(spec -> spec.id != missing_hashed.id, available),
        )
        process = run(
            pipeline(ignorestatus(audit_command(incomplete));
                stdout = devnull, stderr = devnull),
        )
        @test !success(process)
    end
end
