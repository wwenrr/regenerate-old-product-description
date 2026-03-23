#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

usage() {
  cat <<'EOF'
Usage:
  ./split-jsonl-batches.sh <path-to-jsonl> [batch-size] [dataset-name]

Example:
  ./split-jsonl-batches.sh /tmp/products.jsonl 50 products_20260323
EOF
}

if [[ $# -lt 1 || $# -gt 3 ]]; then
  usage
  exit 1
fi

INPUT_PATH="$1"
BATCH_SIZE="${2:-50}"
DATASET_NAME="${3:-}"

if [[ ! -f "$INPUT_PATH" ]]; then
  echo "Input file not found: $INPUT_PATH" >&2
  exit 1
fi

if [[ ! "$BATCH_SIZE" =~ ^[1-9][0-9]*$ ]]; then
  echo "Batch size must be a positive integer." >&2
  exit 1
fi

if [[ -z "$DATASET_NAME" ]]; then
  base_name="$(basename "$INPUT_PATH")"
  DATASET_NAME="${base_name%.jsonl}"
fi

DATA_ROOT="data"
DATASET_DIR="$DATA_ROOT/$DATASET_NAME"
BATCH_DIR="$DATASET_DIR/batch"
mkdir -p "$BATCH_DIR"

# Clean previous parts if dataset already exists.
rm -f "$BATCH_DIR"/part-*.jsonl

awk -v batch="$BATCH_SIZE" -v outdir="$BATCH_DIR" '
  NF {
    file_idx = int(count / batch) + 1
    file_path = sprintf("%s/part-%04d.jsonl", outdir, file_idx)
    print $0 >> file_path
    count++
  }
  END {
    print count > (outdir "/.total_count")
    print int((count + batch - 1) / batch) > (outdir "/.part_count")
  }
' "$INPUT_PATH"

total_count="$(cat "$BATCH_DIR/.total_count")"
part_count="$(cat "$BATCH_DIR/.part_count")"
rm -f "$BATCH_DIR/.total_count" "$BATCH_DIR/.part_count"

if [[ "$total_count" -eq 0 ]]; then
  echo "No JSONL items found in: $INPUT_PATH" >&2
  rm -f "$BATCH_DIR"/part-*.jsonl "$DATASET_DIR"/manifest.json
  rmdir "$BATCH_DIR" 2>/dev/null || true
  rmdir "$DATASET_DIR" 2>/dev/null || true
  exit 1
fi

manifest_path="$DATASET_DIR/manifest.json"
{
  printf '{\n'
  printf '  "type": "jsonl-batches",\n'
  printf '  "dataset": "%s",\n' "$DATASET_NAME"
  printf '  "batch_size": %s,\n' "$BATCH_SIZE"
  printf '  "total_items": %s,\n' "$total_count"
  printf '  "parts": [\n'
  i=1
  while [[ "$i" -le "$part_count" ]]; do
    part_rel_path="$BATCH_DIR/part-$(printf '%04d' "$i").jsonl"
    if [[ "$i" -lt "$part_count" ]]; then
      printf '    "%s",\n' "$part_rel_path"
    else
      printf '    "%s"\n' "$part_rel_path"
    fi
    i=$((i + 1))
  done
  printf '  ]\n'
  printf '}\n'
} > "$manifest_path"

rm -f "$INPUT_PATH"
./update-available-files.sh

echo "Created dataset: $DATASET_NAME"
echo "Output folder: $DATASET_DIR"
echo "Items: $total_count"
echo "Parts: $part_count (batch size: $BATCH_SIZE)"
echo "Source file deleted: $INPUT_PATH"
