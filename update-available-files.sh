#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
MANIFEST="available-files.json"

json_escape() {
  local raw="${1-}"
  raw="${raw//\\/\\\\}"
  raw="${raw//\"/\\\"}"
  raw="${raw//$'\n'/ }"
  printf '%s' "$raw"
}

add_entry() {
  local entry="$1"
  if [[ $first -eq 1 ]]; then
    first=0
  else
    printf ',' >> "$MANIFEST"
  fi
  printf '%s' "$entry" >> "$MANIFEST"
}

printf '[' > "$MANIFEST"
first=1

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  add_entry "\"$(json_escape "$f")\""
done < <(find . -maxdepth 1 -type f -name '*.jsonl' -printf '%f\n' | sort)

while IFS= read -r manifest_path; do
  [[ -z "$manifest_path" ]] && continue
  dataset_dir="$(dirname "$manifest_path")"
  dataset_name="$(basename "$dataset_dir")"
  add_entry "{\"type\":\"batched\",\"label\":\"$(json_escape "$dataset_name (batched)")\",\"manifest\":\"$(json_escape "$manifest_path")\",\"source_label\":\"$(json_escape "$dataset_name")\"}"
done < <(find data -mindepth 2 -maxdepth 2 -type f -name 'manifest.json' 2>/dev/null | sort)

printf ']\n' >> "$MANIFEST"
