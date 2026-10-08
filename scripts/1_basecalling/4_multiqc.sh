#!/bin/bash
#$ -cwd
#$ -N cca_multiqc
#$ -o logs/
#$ -j y
#$ -pe shared 4
#$ -l h_data=8G,h_rt=2:00:00
#$ -M dlera@mail
#$ -m bea
#
# Step 4: aggregate the FastQC output into MultiQC reports.
#
#     qsub scripts/4_multiqc.sh          (3_submit.sh already chains this)
#
# Three reports, because the interesting question is not just "are the reads
# clean" but "did the sup re-basecall actually improve them":
#   multiqc_minknow.html  -- the original instrument basecall alone
#   multiqc_dorado.html   -- the sup re-basecall alone
#   multiqc_compare.html  -- both, with minknow_*/dorado_* sample prefixes so
#                            the per-barcode quality curves overlay directly
#
# Thread cap, not optional: MultiQC 1.35 pulls in polars, whose Rayon pool sizes
# itself to the HOST core count. On a 72-core node each worker's arena
# reservation overruns the job's address-space cap and polars dies with
# "memory allocation of 1520 bytes failed" -- despite the real footprint being
# ~190 MB. It ran fine on the 4-core login node, which is what makes this look
# like a memory shortage when it is really a thread-count problem. These must be
# exported before multiqc starts, since polars fixes its pool size at import.
set -euo pipefail

export POLARS_MAX_THREADS=4
export RAYON_NUM_THREADS=4
export OMP_NUM_THREADS=4

PROJ="${PROJ:-/u/scratch/d/dlera/annabelle_metagenome/cca-metagenome}"
source "$PROJ/scripts/qc_paths.sh"
activate_env

run_report() {
    local name="$1" title="$2"; shift 2
    echo "[$(date)] multiqc -> ${name}.html"
    multiqc \
        --force \
        --title "$title" \
        --filename "${name}.html" \
        --outdir "$MULTIQC_DIR" \
        "$@"
}

run_report multiqc_minknow "AC_Meta -- MinKNOW basecall (fastq_pass)" "$FASTQC_DIR/minknow"
run_report multiqc_dorado  "AC_Meta -- dorado sup re-basecall"        "$FASTQC_DIR/dorado"
run_report multiqc_compare "AC_Meta -- MinKNOW vs dorado sup"         "$FASTQC_DIR/minknow" "$FASTQC_DIR/dorado"

n=$(ls "$MULTIQC_DIR"/*.html 2>/dev/null | wc -l)
[ "$n" -eq 3 ] || { echo "expected 3 reports, got $n" >&2; exit 1; }

echo "[$(date)] done"
ls -la "$MULTIQC_DIR"/*.html
