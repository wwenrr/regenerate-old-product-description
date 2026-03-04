#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
MANIFEST="available-files.json"
echo -n '[' > "$MANIFEST"
first=1
shopt -s nullglob
while IFS= read -r f; do
  [[ $first -eq 1 ]] && first=0 || echo -n ',' >> "$MANIFEST"
  printf '"%s"' "$f" >> "$MANIFEST"
done < <(printf '%s\n' *.jsonl | sort)
shopt -u nullglob
echo ']' >> "$MANIFEST"
