#!/bin/bash
#$ -cwd
#$ -N cca_assembly
#$ -o logs/
#$ -j y
#$ -pe shared 4
#$ -l h_data=8G,h_rt=8:00:00
#$ -M sophieeilersen@gmail.com
#$ -m a
#
# Step 7: metaFlye assemblies of the UNFILTERED (trimmed, host included) reads.
#   task 1 = CCA co-assembly, barcodes 01-14  -> assembly/unfiltered/cca_coassembly/
#   task 2 = positive control, barcode19       -> assembly/unfiltered/control_pos/
#   task 3 = negative control, barcode18       -> assembly/unfiltered/control_neg/
#
# Co-assembly: most CCA barcodes have only a few Mbp of reads (less than one
# bacterial genome), so they are pooled into one assembly. Reads from each
# barcode are mapped back to it later for per-sample abundance. The controls are
# assembled on their own so they never mix with the samples. Water (15-17) is
# left out for now.
#
# Submit all three as an array:
#     qsub -t 1-3 scripts/7_assembly.sh
# Time limit is 8 h on purpose: other labs' nodes on Hoffman2 cap outside jobs
# at 8 h, so a longer request waits much longer in the queue. If a task hits the
# limit, resubmit the same task (e.g. -t 1); it resumes from Flye's last
# finished stage instead of starting over.
set -euo pipefail

PROJ="${PROJ:-/u/scratch/s/seiler/annabelle_metagenome/cca-metagenome}"
source /u/home/s/seiler/miniforge3/etc/profile.d/conda.sh
conda activate assembly

IN_DIR="$PROJ/trimmed/dorado"        # unfiltered = chopper-trimmed reads
SUFFIX="trimmed.fastq.gz"
THREADS="${NSLOTS:-4}"

# Which barcodes go into each assembly (from CCA_Project_Metadata.xlsx).
case "$SGE_TASK_ID" in
    1) name=cca_coassembly; barcodes="01 02 03 04 05 06 07 08 09 10 11 12 13 14" ;;
    2) name=control_pos;    barcodes="19" ;;
    3) name=control_neg;    barcodes="18" ;;
    *) echo "task ${SGE_TASK_ID}: use -t 1-3" >&2; exit 1 ;;
esac

out="$PROJ/assembly/unfiltered/$name"
mkdir -p "$PROJ/assembly/unfiltered"

# Collect the read files, skipping any that are missing or empty.
reads=()
for b in $barcodes; do
    f="$IN_DIR/dorado_barcode${b}.${SUFFIX}"
    if [ -s "$f" ] && [ "$(zcat "$f" | head -c1 | wc -c)" -gt 0 ]; then
        reads+=( "$f" )
    else
        echo "  skipping barcode${b}: no reads in $f"
    fi
done
[ "${#reads[@]}" -gt 0 ] || { echo "no input reads found for $name" >&2; exit 1; }

echo "[$(date)] task ${SGE_TASK_ID}: $name, ${#reads[@]} barcode(s)"
printf '  %s\n' "${reads[@]}"
echo "  output: $out"

# --nano-hq: dorado SUP reads (R10, Q20-ish). --meta: uneven coverage across
# many genomes, the metagenome mode. Flye takes all files at once.
if [ -f "$out/params.json" ]; then
    echo "  previous run found -> resuming"
    flye --resume --out-dir "$out" --threads "$THREADS"
else
    flye --nano-hq "${reads[@]}" \
         --meta \
         --out-dir "$out" \
         --threads "$THREADS"
fi

echo "[$(date)] done"
ls -la "$out/assembly.fasta"
grep -c ">" "$out/assembly.fasta" | xargs echo "  contigs:"
