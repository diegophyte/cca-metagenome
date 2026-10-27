#!/bin/bash
#$ -cwd
#$ -N cca_fastqc_trimmed
#$ -o logs/
#$ -j y
#$ -pe shared 2
#$ -l h_data=8G,h_rt=8:00:00
#$ -M sophieeilersen@gmail.com
#$ -m a
#
# Step 5: FastQC over the chopper-trimmed dorado reads -- one report per barcode.
# Same settings as step 3, so the reports can be compared to the untrimmed ones.
#
# Submit as an array sized to the number of trimmed files, e.g.:
#     qsub -t 1-$(ls trimmed/dorado/*.trimmed.fastq.gz | wc -l) scripts/5_fastqc_trimmed.sh
set -euo pipefail

PROJ="${PROJ:-/u/scratch/s/seiler/annabelle_metagenome/cca-metagenome}"
source /u/home/s/seiler/miniforge3/etc/profile.d/conda.sh
conda activate chopper

TRIM_DIR="${TRIM_DIR:-$PROJ/trimmed}"
OUT_DIR="${OUT_DIR:-$PROJ/results/read-qc/fastqc-trimmed/dorado}"

# Task N handles the Nth trimmed file (sorted by name).
files=( "$TRIM_DIR"/dorado/*.trimmed.fastq.gz )
idx=$(( SGE_TASK_ID - 1 ))
[ "$idx" -lt "${#files[@]}" ] || { echo "no file for task ${SGE_TASK_ID} (${#files[@]} files)" >&2; exit 1; }
input="${files[$idx]}"

TMP="${TMPDIR:-/u/scratch/s/seiler/tmp}/fastqc_${JOB_ID}_${SGE_TASK_ID}"
mkdir -p "$TMP" "$OUT_DIR"
trap 'rm -rf "$TMP"' EXIT

echo "[$(date)] task ${SGE_TASK_ID}"
echo "  input: $input"

fastqc \
    --threads 1 \
    --memory 10000 \
    --dir "$TMP" \
    --outdir "$OUT_DIR" \
    "$input"

echo "[$(date)] done"
ls -la "$OUT_DIR" | grep "$(basename "$input" .fastq.gz)_fastqc" || true
