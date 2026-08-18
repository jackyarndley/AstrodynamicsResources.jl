using Test
using TOML

include(joinpath(@__DIR__, "..", "scripts", "lib", "catalog_editor.jl"))
using .CatalogEditor

@testset "inline catalogue metadata editor" begin
    mktempdir() do root
        mkpath(joinpath(root, "catalog"))
        path = joinpath(root, "catalog", "Resources.toml")
        write(
            path,
            """
            [[resource]]
            name = "single"
            url = "https://fixtures.invalid/single.dat"

            [[resource]]
            name = "multi"

              [[resource.files]]
              url = "https://fixtures.invalid/a.dat"

              [[resource.files]]
              url = "https://fixtures.invalid/b.dat"
            """,
        )

        single = Dict{String, Any}(
            "name" => "single",
            "source_url" => "https://fixtures.invalid/single.dat",
            "source_filename" => "single.dat",
            "source_sha256" => repeat("1", 64),
            "source_size_bytes" => 10,
            "archive_sha256" => repeat("2", 64),
            "archive_size_bytes" => 20,
            "git_tree_sha1" => repeat("3", 40),
            "asset" => "single.tar.gz",
        )
        multi = Dict{String, Any}(
            "name" => "multi",
            "source_url" => "https://fixtures.invalid/a.dat",
            "source_filename" => "a.dat",
            "archive_sha256" => repeat("4", 64),
            "archive_size_bytes" => 40,
            "git_tree_sha1" => repeat("5", 40),
            "asset" => "multi.tar.gz",
            "files" => [
                Dict{String, Any}(
                    "url" => "https://fixtures.invalid/a.dat",
                    "filename" => "a.dat",
                    "sha256" => repeat("6", 64),
                    "size_bytes" => 6,
                ),
                Dict{String, Any}(
                    "url" => "https://fixtures.invalid/b.dat",
                    "filename" => "b.dat",
                    "sha256" => repeat("7", 64),
                    "size_bytes" => 7,
                ),
            ],
        )

        changed = update_reports!(root, [single, multi])
        @test changed == [path]
        parsed = TOML.parsefile(path)
        entries = Dict(entry["name"] => entry for entry in parsed["resource"])

        @test entries["single"]["sha256"] == repeat("1", 64)
        @test entries["single"]["artifact_sha256"] == repeat("2", 64)
        @test entries["single"]["git_tree_sha1"] == repeat("3", 40)
        @test entries["multi"]["artifact_sha256"] == repeat("4", 64)
        @test entries["multi"]["files"][1]["sha256"] == repeat("6", 64)
        @test entries["multi"]["files"][2]["sha256"] == repeat("7", 64)

        @test isempty(update_reports!(root, [single, multi]))
    end
end
