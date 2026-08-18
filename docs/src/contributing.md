# Adding resources

## Immutable data

Add a declaration with the CLI:

```sh
julia --project=. scripts/catalog.jl add example https://authoritative.example/example.dat
```

or edit a catalogue TOML file directly:

```toml
[[resource]]
name = "example"
url = "https://authoritative.example/path/example.dat"
```

The name must be a lowercase Julia-style identifier and the URL must use HTTPS.
The committed declaration asserts that the repository may redistribute the
unchanged upstream bytes under the recorded terms. License terms are resolved
from provider-level `[licenses]` tables; add `license` and `license_url` only
to override a provider default.

After merge, `.github/workflows/cache-resources.yml`:

1. derives the canonical release and `<name>.tar.gz` asset name;
2. adopts an existing canonical archive if one is already published;
3. otherwise downloads the upstream source with retry/resume support;
4. rejects empty files and HTML error pages;
5. computes and verifies source SHA-256 values;
6. packages `data/<upstream filename>` plus `provenance.toml` deterministically;
7. uploads the archive without overwriting different bytes; and
8. opens a PR writing the source, archive, metadata, and artifact-tree hashes
   directly into every successful resource declaration.

A failure in one matrix member does not discard successful reports. Therefore a
resource that was successfully published is adopted/recorded rather than built
again on the next run.

A completed single-file immutable declaration looks like:

```toml
[[resource]]
name = "example"
sha256 = "<source SHA-256>"
artifact_sha256 = "<release archive SHA-256>"
git_tree_sha1 = "<Julia artifact tree SHA-1>"
url = "https://authoritative.example/path/example.dat"
```

`size_bytes` and `artifact_size_bytes` are recorded as diagnostics. If a
resource has `metadata_url`, `metadata_sha256` is recorded as well. Multi-file
resources put `sha256` and `size_bytes` beside each `[[resource.files]]` URL.

The catalogue is the persistent source of truth. `Artifacts.toml` is generated
ephemerally only when calling Julia's artifact installer; there is no committed
resource lock database.

Use optional `metadata_url` for an inseparable comment/readme file. Use
`filename`, `mirrors`, `category`, or `provider` only when inference is wrong.

### Star catalogues

Star catalogues are ordinary immutable resources. Give them
`category = "star_catalogue"` and the CDS ReadMe as `metadata_url`. When an
upstream product is split across several files (Tycho-2 is 20 gzipped parts),
declare each part in a `[[resource.files]]` block instead of `url`; parts are
returned by `resource_paths` in declaration order.

## Live data

Add `live = true`. The default TTL is six hours. Override it only when needed:

```toml
[[resource]]
name = "example_live"
url = "https://authoritative.example/current.txt"
live = true
ttl = 3600
```

Live resources are never mirrored into a release and never update at import.

### Auditing NAIF SPKs

The active generic SPK tree can be compared with the catalogue by running:

```text
julia --project=. scripts/audit_naif_spk.jl
```

The maintainer-only command reports new upstream files, catalogued files,
catalog entries no longer present in the active tree, and archive directories
that it intentionally ignores. It never edits the catalogue.
