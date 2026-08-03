# Adding resources

## Immutable data

Add two lines to `catalog/Resources.toml`:

```toml
[[resource]]
name = "example"
url = "https://authoritative.example/path/example.dat"
```

The name must be a lowercase Julia-style identifier and the URL must use HTTPS.
The committed declaration asserts that the repository may redistribute the
unchanged upstream bytes. Check the upstream terms before committing.

After merge, `.github/workflows/cache-resources.yml`:

1. detects that `example` is not locked or published;
2. downloads it into a persistent content-addressed Actions cache;
3. rejects empty files and HTML error pages;
4. computes the source SHA-256;
5. packages `data/<upstream filename>` and `provenance.toml` deterministically;
6. uploads `example.tar.gz` without overwriting an existing asset; and
7. opens a PR with generated `ResourceLock.toml` and `Artifacts.toml` changes.

Use optional `metadata_url` for an inseparable comment/readme file. Use
`filename`, `mirrors`, `category`, or `provider` only when inference is wrong.

The command-line helper performs the same minimal edit:

```sh
julia --project=. scripts/add_resource.jl example https://authoritative.example/example.dat
```

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
