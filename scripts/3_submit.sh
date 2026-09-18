#!/bin/bash
# Build the FastQC manifest, submit the array, and chain MultiQC behind it.
#
#     ./scripts/3_submit.sh            submit both jobs
#     ./scripts/3_submit.sh --dry-run  build the manifest and print it only
#
# One manifest line per barcode per basecaller:  dataset <TAB> barcode <TAB> input
# where input is a directory (minknow, many chunk files) or a single fastq.gz
# (dorado). 3_fastqc.sh branches on which it got.
set -euo pipefail

PROJ="${PROJ:-/u/scratch/d/dlera/annabelle_metagenome/cca-metagenome}"
source "$PROJ/scripts/qc_paths.sh"
cd "$PROJ"                              # the job scripts use #$ -cwd + -o logs/

: > "$MANIFEST"

for d in "$MINKNOW_DIR"/*/; do
    d="${d%/}"
    compgen -G "$d/*.fastq.gz" > /dev/null || continue    # skip empty barcodes
    printf 'minknow\t%s\t%s\n' "$(basename "$d")" "$d" >> "$MANIFEST"
done

for f in "$DORADO_DIR"/*.fastq.gz; do
    [ -e "$f" ] || continue
    printf 'dorado\t%s\t%s\n' "$(basename "$f" .fastq.gz)" "$f" >> "$MANIFEST"
done

N=$(wc -l < "$MANIFEST")
[ "$N" -gt 0 ] || { echo "manifest is empty -- check MINKNOW_DIR / DORADO_DIR" >&2; exit 1; }

echo "manifest: $MANIFEST ($N tasks)"
printf '  %-8s %d barcodes\n' minknow "$(grep -c '^minknow' "$MANIFEST")"
printf '  %-8s %d barcodes\n' dorado  "$(grep -c '^dorado'  "$MANIFEST")"

if [ "${1:-}" = "--dry-run" ]; then
    echo; cat "$MANIFEST"; exit 0
fi

qsub -t 1-"$N" scripts/3_fastqc.sh
qsub -hold_jid cca_fastqc scripts/4_multiqc.sh

echo
echo "reports will land in $MULTIQC_DIR"
