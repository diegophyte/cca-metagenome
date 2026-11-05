#!/bin/bash
#SBATCH --job-name=cca_binning
#SBATCH --output=logs/cca_binning.%j.out
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=4G
#SBATCH --time=24:00:00
#SBATCH --mail-user=sophieeilersen@gmail.com
#SBATCH --mail-type=FAIL
##SBATCH --qos=highp          # Medina lab node: remove one '#' to turn on (see notes)
##SBATCH --account=pi_XXXX    # only needed if `h2 whoami` lists more than one account
#
# Step 8: bin the unfiltered CCA co-assembly into genomes (MAGs).
#   1. map each CCA sample's trimmed reads back to the co-assembly (minimap2)
#      -> per-sample coverage of every contig, the main signal for binning
#   2. MetaBAT2 bins   -> binning/unfiltered/cca_coassembly/metabat2/
#   3. SemiBin2 bins   -> binning/unfiltered/cca_coassembly/semibin2/
# Two binners are run so their bins can be compared and scored with CheckM2
# in step 9.
#
# Slurm (Hoffman2 Rocky 9). Submit from the project folder:
#     sbatch scripts/8_binning.sh
# Each stage is skipped if its output already exists, so if the job hits the
# time limit, resubmit it and it continues where it stopped.
# Without highp, jobs run in the campus partition (max 24 h). With
# --qos=highp they run on the lab's own node (max 14 days).
set -euo pipefail

PROJ="${PROJ:-/u/scratch/s/seiler/annabelle_metagenome/cca-metagenome}"

# Every Hoffman2 Slurm job starts with an Intel module loaded that conflicts
# with many tools, so clear modules before activating conda.
module purge
source /u/home/s/seiler/miniforge3/etc/profile.d/conda.sh
conda activate binning

THREADS="${SLURM_CPUS_PER_TASK:-2}"
ASM="$PROJ/assembly/unfiltered/cca_coassembly/assembly.fasta"
READS_DIR="$PROJ/trimmed/dorado"
OUT="$PROJ/binning/unfiltered/cca_coassembly"
BAM_DIR="$OUT/mapping"

# Same CCA barcodes that went into the co-assembly (CCA_Project_Metadata.xlsx).
CCA_BARCODES="01 02 03 04 05 06 07 08 09 10 11 12 13 14"
MIN_LEN=1500     # ignore contigs shorter than this (tiny repeats etc.)

[ -s "$ASM" ] || { echo "co-assembly not found: $ASM" >&2; exit 1; }
mkdir -p "$BAM_DIR"
echo "[$(date)] job ${SLURM_JOB_ID:-local}: binning $ASM with $THREADS threads"

# ---- 1. map each sample back to the co-assembly ---------------------------
for b in $CCA_BARCODES; do
    reads="$READS_DIR/dorado_barcode${b}.trimmed.fastq.gz"
    bam="$BAM_DIR/barcode${b}.bam"
    if [ -s "$bam.bai" ]; then
        echo "  mapping barcode${b}: already done"
        continue
    fi
    echo "[$(date)]  mapping barcode${b}"
    # -F 0x904 keeps primary, mapped alignments only (drops unmapped,
    # secondary and supplementary records), which is what depth tools expect.
    minimap2 -ax map-ont -t "$THREADS" "$ASM" "$reads" 2>/dev/null \
        | samtools view -b -F 0x904 - \
        | samtools sort -@ "$THREADS" -o "$bam" -
    samtools index "$bam"
done
bams=( "$BAM_DIR"/barcode*.bam )

# Reads from each sample that landed on the assembly (worth recording).
for bam in "${bams[@]}"; do
    echo "  $(basename "$bam" .bam): $(samtools view -c "$bam") reads mapped"
done > "$OUT/mapped_reads_per_sample.txt"
cat "$OUT/mapped_reads_per_sample.txt"

# ---- 2. MetaBAT2 ----------------------------------------------------------
if [ ! -d "$OUT/metabat2" ] || [ -z "$(ls "$OUT/metabat2" 2>/dev/null)" ]; then
    echo "[$(date)]  MetaBAT2"
    jgi_summarize_bam_contig_depths --outputDepth "$OUT/metabat2_depth.txt" "${bams[@]}"
    mkdir -p "$OUT/metabat2"
    metabat2 -i "$ASM" -a "$OUT/metabat2_depth.txt" \
             -o "$OUT/metabat2/bin" -m "$MIN_LEN" -t "$THREADS"
else
    echo "  MetaBAT2: already done"
fi

# ---- 3. SemiBin2 ----------------------------------------------------------
if [ ! -d "$OUT/semibin2/output_bins" ]; then
    echo "[$(date)]  SemiBin2"
    SemiBin2 single_easy_bin \
        --input-fasta "$ASM" \
        --input-bam "${bams[@]}" \
        --output "$OUT/semibin2" \
        --sequencing-type long_read \
        --min-len "$MIN_LEN" \
        --threads "$THREADS"
else
    echo "  SemiBin2: already done"
fi

echo "[$(date)] done"
echo "  MetaBAT2 bins: $(ls "$OUT"/metabat2/*.fa 2>/dev/null | wc -l)"
echo "  SemiBin2 bins: $(ls "$OUT"/semibin2/output_bins/* 2>/dev/null | wc -l)"
