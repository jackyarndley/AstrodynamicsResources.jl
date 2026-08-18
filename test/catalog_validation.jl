using Test
using AstrodynamicsResources

function invalid_catalog(resource_text::String, bundle_text::String = "")
    return mktempdir() do directory
        write(joinpath(directory, "Resources.toml"), resource_text)
        write(joinpath(directory, "bundles.toml"), bundle_text)
        try
            withenv("ASTRODYNAMICS_RESOURCES_CATALOG" => directory) do
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
license = "test terms"
license_url = "https://fixtures.invalid/terms"
"""

@testset "minimal and invalid catalogues" begin
    mktempdir() do directory
        write(joinpath(directory, "Resources.toml"), VALIDATION_RESOURCE)
        try
            withenv("ASTRODYNAMICS_RESOURCES_CATALOG" => directory) do
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

    mktempdir() do directory
        write(
            joinpath(directory, "Resources.toml"),
            VALIDATION_RESOURCE * """
            sha256 = "$(repeat("0", 64))"
            artifact_sha256 = "$(repeat("1", 64))"
            git_tree_sha1 = "$(repeat("2", 40))"
            """,
        )
        try
            withenv("ASTRODYNAMICS_RESOURCES_CATALOG" => directory) do
                AstrodynamicsResources._CATALOG_LOADED[] = false
                AstrodynamicsResources._load_catalog!()
                @test resource(:one).available
                @test resource(:one).metadata["source_sha256"] == repeat("0", 64)
                @test resource(:one).metadata["artifact_sha256"] == repeat("1", 64)
            end
        finally
            AstrodynamicsResources._CATALOG_LOADED[] = false
            AstrodynamicsResources._load_catalog!()
        end
    end

    invalid_catalog(
        VALIDATION_RESOURCE * replace(VALIDATION_RESOURCE, "one.txt" => "two.txt")
    )

    invalid_catalog(
        VALIDATION_RESOURCE * """
            [[resource]]
            name = "two"
            url = "https://fixtures.invalid/one.txt"
            """
    )

    invalid_catalog(
        replace(VALIDATION_RESOURCE, "name = \"one\"" => "name = \"Not Safe\"")
    )
    invalid_catalog(replace(VALIDATION_RESOURCE, "https://" => "http://"))

    invalid_catalog(
        """
        [[resource]]
        name = "unlicensed"
        url = "https://fixtures.invalid/unlicensed.txt"
        """
    )

    invalid_catalog(
        replace(
            VALIDATION_RESOURCE,
            "https://fixtures.invalid/terms" => "http://fixtures.invalid/terms",
        )
    )

    invalid_catalog(
        """
        [[resource]]
        name = "both"
        url = "https://fixtures.invalid/both.txt"

          [[resource.files]]
          url = "https://fixtures.invalid/part.txt"
        """
    )

    invalid_catalog(
        """
        [[resource]]
        name = "nourl"
        files = []
        """
    )

    invalid_catalog(
        """
        [[resource]]
        name = "duplicates"

          [[resource.files]]
          url = "https://fixtures.invalid/a.txt"

          [[resource.files]]
          url = "https://fixtures.invalid/a.txt"
        """
    )

    invalid_catalog(
        """
        [[resource]]
        name = "unsafe_file"

          [[resource.files]]
          url = "https://fixtures.invalid/sub/dir.txt"
          filename = "../dir.txt"
        """
    )

    invalid_catalog(
        """
        [[resource]]
        name = "live_files"
        live = true

          [[resource.files]]
          url = "https://fixtures.invalid/a.txt"
        """
    )

    invalid_catalog(
        VALIDATION_RESOURCE * """
        artifact_sha256 = "$(repeat("0", 64))"
        """
    )

    invalid_catalog(
        VALIDATION_RESOURCE, """
        [bundle]
        missing = ["not_there"]
        """
    )
    invalid_catalog(
        VALIDATION_RESOURCE, """
        [bundle]
        a = ["b"]
        b = ["a"]
        """
    )
    invalid_catalog(
        VALIDATION_RESOURCE, """
        [bundle]
        duplicate = ["one", "one"]
        """
    )
end
