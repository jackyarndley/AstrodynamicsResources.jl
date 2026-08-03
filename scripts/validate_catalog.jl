#!/usr/bin/env julia

using AstrodynamicsResources

validate_catalog()
all_resources = list_resources()
immutable = list_resources(backend=:artifact)
live = list_resources(backend=:scratch)
cached = count(spec -> spec.available, immutable)
println("catalogue valid: $(length(all_resources)) resources ",
        "($(length(immutable)) immutable, $(length(live)) live, $cached cached)")
