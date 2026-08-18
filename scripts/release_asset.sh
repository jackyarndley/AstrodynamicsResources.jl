#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"

usage() {
  cat <<'EOF'
usage: release_asset.sh COMMAND RELEASE [ASSET [DESTINATION]]

Commands:
  list RELEASE                 List asset name, digest, and numeric asset ID.
  find RELEASE ASSET           Print matching asset name, digest, and ID, or nothing.
  download RELEASE ASSET DEST  Download and SHA-256 verify one release asset.
EOF
}

release_id() {
  gh api "repos/${GITHUB_REPOSITORY}/releases/tags/$1" --jq '.id'
}

list_assets() {
  local release="$1"
  local id
  id=$(release_id "$release")
  gh api --paginate "repos/${GITHUB_REPOSITORY}/releases/${id}/assets?per_page=100" \
    --jq '.[] | [.name, (.digest // ""), (.id | tostring)] | @tsv'
}

find_asset() {
  local release="$1"
  local asset="$2"
  list_assets "$release" | awk -F '\t' -v name="$asset" '$1 == name { print; exit }'
}

command=${1:-}
case "$command" in
  list)
    [ "$#" -eq 2 ] || { usage >&2; exit 2; }
    list_assets "$2"
    ;;
  find)
    [ "$#" -eq 3 ] || { usage >&2; exit 2; }
    find_asset "$2" "$3"
    ;;
  download)
    [ "$#" -eq 4 ] || { usage >&2; exit 2; }
    row=$(find_asset "$2" "$3")
    [ -n "$row" ] || { echo "asset not found: $2/$3" >&2; exit 1; }
    IFS=$'\t' read -r name digest asset_id <<<"$row"
    mkdir -p "$(dirname "$4")"
    gh api -H 'Accept: application/octet-stream' \
      "repos/${GITHUB_REPOSITORY}/releases/assets/${asset_id}" > "$4"
    if [ -n "$digest" ]; then
      local_digest="sha256:$(sha256sum "$4" | cut -d' ' -f1)"
      [ "$local_digest" = "$digest" ] || {
        echo "digest mismatch for $2/$3: expected $digest, got $local_digest" >&2
        exit 1
      }
    fi
    printf '%s\n' "$digest"
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
