using Test
using AstrodynamicsResources
using Artifacts
using SHA
import Pkg

include(joinpath(@__DIR__, "..", "scripts", "lib", "artifact_archive.jl"))
using .ArtifactArchiveSupport

@testset "dynamic artifact API with tiny fixture" begin
    hash = Pkg.Artifacts.create_artifact() do directory
        cp(
            joinpath(@__DIR__, "fixtures", "artifact", "data"),
            joinpath(directory, "data"); force = true,
        )
        cp(
            joinpath(@__DIR__, "fixtures", "artifact", "provenance.toml"),
            joinpath(directory, "provenance.toml"); force = true,
        )
    end
    mktempdir() do temp
        archive_one = joinpath(temp, "one.tar.gz")
        archive_two = joinpath(temp, "two.tar.gz")
        deterministic_archive_artifact(hash, archive_one)
        deterministic_archive_artifact(hash, archive_two)
        @test read(archive_one) == read(archive_two)

        archive_sha = open(archive_one, "r") do io
            bytes2hex(SHA.sha256(io))
        end
        spec = ResourceSpec(
            :fixture_artifact, Symbol[], "Fixture", "Tiny fixture", :fixture,
            :tests, "1", ArtifactBackend("fixture_artifact"),
            [ResourceFile("data/tiny_kernel.bsp", :spk, true)],
            Dict{String, Any}(
                "format" => "SPICE SPK",
                "git_tree_sha1" => string(hash),
                "artifact_sha256" => archive_sha,
            ),
            true,
        )
        first_path = only(AstrodynamicsResources._artifact_paths(spec))
        second_path = only(AstrodynamicsResources._artifact_paths(spec))
        @test first_path == second_path
        @test isfile(first_path)
        @test read(first_path, String) ==
            read(
            joinpath(@__DIR__, "fixtures", "artifact", "data", "tiny_kernel.bsp"),
            String,
        )
        @test Artifacts.artifact_exists(hash)
    end
end

@testset "verification and status" begin
    @test !verify_resource(:de440s)
    @test !resource_status(:iers_finals2000a).available
    @test resource_status(:iers_finals2000a).backend == :scratch
    @test_throws ArgumentError clear_resource!(:de440s)
end
