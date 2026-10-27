#!/bin/bash
#$ -cwd
#$ -N cca_chopper
#$ -o logs/
#$ -j y
#$ -pe shared 2
#$ -l h_data=8G,h_rt=8:00:00
#$ -M sophieeilersen@gmail.com
#$ -m a
#
# Step 4: chopper over the dorado read set -- one trimmed FASTQ per barcode.
# Drops reads with mean Q < 7 and crops the first 10 bases of each read.
#
# Uses the same manifest as step 3 (one line per dataset/barcode). Submit as an
# array sized to the manifest, e.g.:
#     qsub -t 1-$(wc -l < "$MANIFEST") scripts/4_chopper.sh
set -euo pipefail

PROJ="${PROJ:-/u/scratch/s/seiler/annabelle_metagenome/cca-metagenome}"
source "$PROJ/scripts/qc_paths.sh"
source /u/home/s/seiler/miniforge3/etc/profile.d/conda.sh
conda activate chopper

TRIM_DIR="${TRIM_DIR:-$PROJ/trimmed}"

line=$(sed -n "${SGE_TASK_ID}p" "$MANIFEST")
[ -n "$line" ] || { echo "no manifest line ${SGE_TASK_ID} in $MANIFEST" >&2; exit 1; }
dataset=$(echo "$line" | cut -f1)
sample=$(echo "$line"  | cut -f2)
input=$(echo "$line"   | cut -f3)

# Only trim the dorado set; minknow tasks exit immediately without doing anything.
[ "$dataset" = "dorado" ] || { echo "skipping ${dataset} / ${sample} (not dorado)"; exit 0; }

mkdir -p "$TRIM_DIR/$dataset"
out="$TRIM_DIR/$dataset/${dataset}_${sample}.trimmed.fastq.gz"

echo "[$(date)] task ${SGE_TASK_ID}  ${dataset} / ${sample}"
echo "  input: $input"
echo "  output: $out"

# Same merging as step 3: the minknow set is many chunk files per barcode, so
# stream them all in together to get ONE trimmed file per barcode.
if [ -d "$input" ]; then
    src=( "$input"/*.fastq.gz )
    echo "  merging ${#src[@]} chunk files"
else
    src=( "$input" )
fi

zcat "${src[@]}" \
    | chopper \
        --quality 7 \
        --trim-approach fixed-crop \
        --headcrop 10 \
        --threads 2 \
    | gzip > "$out"

echo "[$(date)] done"
ls -la "$out"
