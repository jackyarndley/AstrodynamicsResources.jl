function invalid_catalog(resource_text::String, bundle_text::String="")
    mktempdir() do directory
        write(joinpath(directory, "resources.toml"), resource_text)
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
id = "one"
aliases = []
title = "One"
description = "Fixture"
category = "fixture"
provider = "tests"
version = "1"
backend = "artifact"
artifact_name = "one"
available = false
files = [{path = "data/one.txt", role = "data", primary = true}]
source_url = "https://fixtures.invalid/one.txt"
source_filename = "one.txt"
format = "text"
citation = "Test fixture"
license = "CC0"
redistribution = "unresolved"
retrieved_at = "2026-01-01"
"""

@testset "invalid catalogues are rejected" begin
    invalid_catalog(VALIDATION_RESOURCE * replace(
        VALIDATION_RESOURCE, "https://fixtures.invalid/one.txt" =>
        "https://fixtures.invalid/two.txt"))

    duplicate_aliases = replace(VALIDATION_RESOURCE, "aliases = []" =>
                                "aliases = [\"shared\"]") *
        replace(replace(VALIDATION_RESOURCE, "id = \"one\"" => "id = \"two\""),
                "aliases = []" => "aliases = [\"shared\"]",
                "https://fixtures.invalid/one.txt" => "https://fixtures.invalid/two.txt")
    invalid_catalog(duplicate_aliases)

    invalid_catalog(VALIDATION_RESOURCE, """
    [[bundle]]
    id = "missing"
    title = "Missing"
    description = "Missing member"
    members = ["not_there"]
    """)

    invalid_catalog(VALIDATION_RESOURCE, """
    [[bundle]]
    id = "a"
    title = "A"
    description = "Cycle"
    members = ["b"]
    [[bundle]]
    id = "b"
    title = "B"
    description = "Cycle"
    members = ["a"]
    """)

    invalid_catalog(VALIDATION_RESOURCE, """
    [[bundle]]
    id = "duplicate"
    title = "Duplicate"
    description = "Duplicate members"
    members = ["one", "one"]
    """)
end
