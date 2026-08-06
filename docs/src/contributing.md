# Adding resources

## Immutable data

Add a declaration with the CLI:

```sh
julia --project=. scripts/catalog.jl add example https://authoritative.example/example.dat
```

or edit `catalog/Resources.toml` directly:

```toml
[[resource]]
name = "example"
url = "https://authoritative.example/path/example.dat"
```

The name must be a lowercase Julia-style identifier and the URL must use HTTPS.
The committed declaration asserts that the repository may redistribute the
unchanged upstream bytes under the recorded terms. License terms are resolved
from the provider-level `[licenses]` table; add `license` and `license_url`
only to override the provider default. Check the upstream terms before
committing.

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

The CLI accepts the same optional flags:

```sh
julia --project=. scripts/catalog.jl add example https://authoritative.example/example.dat \
  --category star_catalogue --license "..." --license-url "https://..."
```

### Star catalogues

Star catalogues are ordinary immutable resources. Give them
`category = "star_catalogue"` and the CDS ReadMe as `metadata_url`:

```toml
[[resource]]
name = "fk5"
url = "https://cdsarc.cds.unistra.fr/ftp/I/149/fk5.dat"
metadata_url = "https://cdsarc.cds.unistra.fr/ftp/I/149/ReadMe"
category = "star_catalogue"
citation = "Fricke et al. 1988, FK5 Part I (VizieR On-line Data Catalogue I/149A)."
```

Hipparcos and Tycho-2 use `provider = "esa"` because their redistribution
terms come from ESA rather than from CDS itself.

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
