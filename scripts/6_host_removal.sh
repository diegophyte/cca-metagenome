#!/bin/bash
#$ -cwd
#$ -N cca_hostremoval
#$ -o logs/
#$ -j y
#$ -pe shared 4
#$ -l h_data=8G,h_rt=12:00:00
#$ -M sophieeilersen@gmail.com
#$ -m a
#
# Step 6: remove CCA (host) reads from the chopper-trimmed dorado reads.
# Maps each barcode to the CCA reference with minimap2 and keeps only the reads
# that did NOT map -> the "filtered" (host-removed) read set.
# The "unfiltered" set is just the step 4 output in trimmed/dorado/, unchanged.
#
# Before submitting: build the index once (see REF_MMI below), then
#     qsub -t 1-$(ls trimmed/dorado/*.trimmed.fastq.gz | wc -l) scripts/6_host_removal.sh
set -euo pipefail

PROJ="${PROJ:-/u/scratch/s/seiler/annabelle_metagenome/cca-metagenome}"
source /u/home/s/seiler/miniforge3/etc/profile.d/conda.sh
conda activate chopper

TRIM_DIR="${TRIM_DIR:-$PROJ/trimmed/dorado}"
REF_MMI="${REF_MMI:-$PROJ/reference/cca_host.mmi}"   # minimap2 index of the CCA reference
OUT_DIR="${OUT_DIR:-$PROJ/host-filtered/dorado}"
STATS_DIR="${STATS_DIR:-$PROJ/results/host-mapping/dorado}"
THREADS="${NSLOTS:-2}"

# Task N handles the Nth trimmed file (sorted by name), same as step 5.
files=( "$TRIM_DIR"/*.trimmed.fastq.gz )
idx=$(( SGE_TASK_ID - 1 ))
[ "$idx" -lt "${#files[@]}" ] || { echo "no file for task ${SGE_TASK_ID} (${#files[@]} files)" >&2; exit 1; }
input="${files[$idx]}"
name=$(basename "$input" .trimmed.fastq.gz)          # e.g. dorado_barcode05

[ -s "$REF_MMI" ] || { echo "reference index not found: $REF_MMI" >&2; exit 1; }
mkdir -p "$OUT_DIR" "$STATS_DIR"

# Empty inputs (barcodes 21/23/24 lost their single read in step 4): nothing to map.
if [ "$(zcat "$input" | head -c1 | wc -c)" -eq 0 ]; then
    echo "skipping $name (no reads)"
    exit 0
fi

bam="$STATS_DIR/${name}.host.bam"
out="$OUT_DIR/${name}.hostfiltered.fastq.gz"

echo "[$(date)] task ${SGE_TASK_ID}  $name"
echo "  input:  $input"
echo "  ref:    $REF_MMI"
echo "  output: $out"

# 1. Map all reads to the CCA reference (map-ont = nanopore preset) and sort.
minimap2 -ax map-ont -t "$THREADS" "$REF_MMI" "$input" \
    | samtools sort -@ "$THREADS" -o "$bam" -
samtools index "$bam"

# 2. Record how many reads were host (mapped) vs not, per barcode.
samtools flagstat "$bam" > "$STATS_DIR/${name}.flagstat.txt"

# 3. Keep only primary reads that did not map (-f 4 = unmapped,
#    -F 0x900 = drop secondary/supplementary records) -> microbial + unknown reads.
samtools fastq -f 4 -F 0x900 "$bam" | gzip > "$out"

echo "[$(date)] done"
echo "  reads in:  $(( $(zcat "$input" | wc -l) / 4 ))"
echo "  reads out: $(( $(zcat "$out" | wc -l) / 4 ))"
ls -la "$out"
