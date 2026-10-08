#!/bin/bash
#$ -cwd
#$ -N cca_fastqc
#$ -o logs/
#$ -j y
#$ -pe shared 2
#$ -l h_data=8G,h_rt=8:00:00
#$ -M dlera@mail
#$ -m bea
#
# Step 3: FastQC over both read sets -- one report per barcode per basecaller.
#
# Submit through the wrapper, which builds the manifest and sizes the array:
#     ./scripts/3_submit.sh
#
# Sizing: a 42 MB / 37k-read barcode took 6.6 s and 1.3 GB RSS, so the largest
# member (dorado barcode20, 6.2 GB gz) should finish in well under an hour.
# 8h and 16 GB is generous headroom; no highp slot needed. (10000 MB is the
# hard ceiling FastQC accepts for --memory.)
set -euo pipefail

PROJ="${PROJ:-/u/scratch/d/dlera/annabelle_metagenome/cca-metagenome}"
source "$PROJ/scripts/qc_paths.sh"
activate_env

line=$(sed -n "${SGE_TASK_ID}p" "$MANIFEST")
[ -n "$line" ] || { echo "no manifest line ${SGE_TASK_ID} in $MANIFEST" >&2; exit 1; }
dataset=$(echo "$line" | cut -f1)
sample=$(echo "$line"  | cut -f2)
input=$(echo "$line"   | cut -f3)

TMP="${TMPDIR:-/u/scratch/d/dlera/tmp}/fastqc_${JOB_ID}_${SGE_TASK_ID}"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

echo "[$(date)] task ${SGE_TASK_ID}  ${dataset} / ${sample}"
echo "  input: $input"

# Both sets are streamed in on stdin so that ONE BARCODE = ONE SAMPLE. The
# minknow set is ~30-73 chunk files per barcode; handing those to FastQC
# individually would give MultiQC 1197 samples instead of 21, and no per-barcode
# view at all. `stdin:<name>` makes FastQC name the report after the barcode
# instead of the file, which also keeps the two basecallers distinguishable in
# the combined report. Concatenated gzip members decompress as one stream, so
# no intermediate merged FASTQ is written.
if [ -d "$input" ]; then
    src=( "$input"/*.fastq.gz )
    echo "  merging ${#src[@]} chunk files"
else
    src=( "$input" )
fi

zcat "${src[@]}" \
    | fastqc \
        --threads 1 \
        --memory 10000 \
        --dir "$TMP" \
        --outdir "$FASTQC_DIR/$dataset" \
        "stdin:${dataset}_${sample}"

echo "[$(date)] done"
ls -la "$FASTQC_DIR/$dataset" | grep "${dataset}_${sample}_fastqc" || true
