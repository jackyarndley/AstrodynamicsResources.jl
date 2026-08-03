function invalid_catalog(resource_text::String, bundle_text::String="";
                         lock_text::String="version = 1\n[resources]\n")
    mktempdir() do directory
        write(joinpath(directory, "Resources.toml"), resource_text)
        write(joinpath(directory, "bundles.toml"), bundle_text)
        write(joinpath(directory, "ResourceLock.toml"), lock_text)
        artifacts = joinpath(directory, "Artifacts.toml")
        write(artifacts, "")
        try
            withenv("ASTRODYNAMICS_RESOURCES_CATALOG" => directory,
                    "ASTRODYNAMICS_RESOURCES_ARTIFACTS_TOML" => artifacts) do
                AstrodynamicsResources._CATALOG_LOADED[] = false
                @test_throws ArgumentError AstrodynamicsResources._load_catalog!()
            end
        finally
            AstrodynamicsResources._CATALOG_LOADED[] = false
            AstrodynamicsResources._load_catalog!()
        end
    end
end

const VALIDATION_RESOURCE = """
[[resource]]
name = "one"
url = "https://fixtures.invalid/one.txt"
"""

@testset "minimal and invalid catalogues" begin
    mktempdir() do directory
        write(joinpath(directory, "Resources.toml"), VALIDATION_RESOURCE)
        write(joinpath(directory, "ResourceLock.toml"), "version = 1\n[resources]\n")
        write(joinpath(directory, "Artifacts.toml"), "")
        try
            withenv("ASTRODYNAMICS_RESOURCES_CATALOG" => directory,
                    "ASTRODYNAMICS_RESOURCES_ARTIFACTS_TOML" =>
                        joinpath(directory, "Artifacts.toml")) do
                AstrodynamicsResources._CATALOG_LOADED[] = false
                AstrodynamicsResources._load_catalog!()
                @test resource(:one).metadata["source_filename"] == "one.txt"
                @test resource(:one).category == :data
                @test !resource(:one).available
            end
        finally
            AstrodynamicsResources._CATALOG_LOADED[] = false
            AstrodynamicsResources._load_catalog!()
        end
    end

    invalid_catalog(VALIDATION_RESOURCE * replace(
        VALIDATION_RESOURCE, "one.txt" => "two.txt"))

    invalid_catalog(VALIDATION_RESOURCE * """
    [[resource]]
    name = "two"
    url = "https://fixtures.invalid/one.txt"
    """)

    invalid_catalog(replace(VALIDATION_RESOURCE, "name = \"one\"" =>
                            "name = \"Not Safe\""))
    invalid_catalog(replace(VALIDATION_RESOURCE, "https://" => "http://"))

    invalid_catalog(VALIDATION_RESOURCE, """
    [bundle]
    missing = ["not_there"]
    """)
    invalid_catalog(VALIDATION_RESOURCE, """
    [bundle]
    a = ["b"]
    b = ["a"]
    """)
    invalid_catalog(VALIDATION_RESOURCE, """
    [bundle]
    duplicate = ["one", "one"]
    """)

    invalid_catalog(VALIDATION_RESOURCE; lock_text="""
    version = 1
    [resources.unknown]
    source_sha256 = "$(repeat("0", 64))"
    """)
end
