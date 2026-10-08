#!/bin/bash
#$ -cwd
#$ -N ac_meta_fq
#$ -o bam2fastq.$JOB_ID.log
#$ -j y
#$ -l h_rt=4:00:00,h_data=4G
#$ -pe shared 4
# Convert the demuxed per-barcode uBAMs into gzipped FASTQ.
#
# Why the pipeline stayed BAM until here: dorado records the barcode call in the
# BC/RG tags and `dorado demux` reads those tags. FASTQ cannot carry them, so
# emitting flat files from the basecaller would have made demuxing impossible.
set -u

OUTDIR=/u/scratch/d/dlera/annabelle_metagenome/basecalled-reads
DEMUX=$OUTDIR/demux
FQ=$OUTDIR/fastq

source /u/local/Modules/default/init/bash
module load samtools/1.15

mkdir -p "$FQ"
TOTAL=0
echo "=== $(date) converting $DEMUX -> $FQ ==="

# dorado writes a MinKNOW-style tree: <exp>/<sample>/<run>/bam_pass/<barcode>/*.bam
# so collapse every bam belonging to one barcode into a single fastq.gz.
for d in $(find "$DEMUX" -type d \( -name 'barcode*' -o -name 'unclassified' \) | sort); do
    bc=$(basename "$d")
    out="$FQ/${bc}.fastq.gz"
    found=0
    : > "$out.tmp"
    for b in "$d"/*.bam; do
        [ -e "$b" ] || continue
        samtools fastq -@ 3 "$b" >> "$out.tmp" 2>/dev/null
        found=1
    done
    if [ "$found" -eq 0 ]; then rm -f "$out.tmp"; continue; fi
    # count before compressing, so we never decompress just to tally
    n=$(( $(wc -l < "$out.tmp") / 4 ))
    pigz -p 4 -c "$out.tmp" > "$out" && rm -f "$out.tmp"
    TOTAL=$(( TOTAL + n ))
    printf "%-14s %10d reads  %8s\n" "$bc" "$n" "$(du -h "$out" | cut -f1)"
done

echo "--- totals ---"
echo "total reads: $TOTAL"
du -sh "$FQ"
echo "=== done $(date) ==="
