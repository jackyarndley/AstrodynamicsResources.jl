# Contributing resources

## Immutable resource

1. Establish the exact authoritative byte stream and filename.
2. Review citation, licence, redistribution status, and provider checksum.
3. Add exact catalogue metadata without changing a semantic alias or bundle.
4. Record an independently computed source SHA-256.
5. Run `scripts/build_artifact.jl` in the scripts environment.
6. Review its provenance, tree hash, archive SHA-256, and deterministic rebuild.
7. Publish to immutable release or object storage without overwriting content.
8. Run `scripts/update_artifacts_toml.jl`, verify installation, and open a PR.

Raw upstream files remain byte-for-byte unchanged. The deterministic artifact
layout is `data/`, optional `metadata/`, and `provenance.toml`.

## Live resource

Add a scratch catalogue entry with authoritative URL(s), TTL, content format,
minimum plausible size, stale policy, conditional-request support, citation,
and provider role. Add a local-server test. Core code does not parse the product.

## Gravity models and licensing

Do not promote a model from `catalog/candidates/gravity.toml` until its original
coefficient file, normalization, degree/order, reference radius, GM, tide
system, citation, source digest, and redistribution conditions are reviewed.
One model is never labelled universally best.

## Discovery review

Discovery scripts write machine-readable TOML and human-readable Markdown
reports. Additions, removals, same-name checksum changes, old-version moves,
frame-definition changes, alias changes, and bundle changes require human
review. Discovery never publishes, deletes, recommends, or changes an alias.

