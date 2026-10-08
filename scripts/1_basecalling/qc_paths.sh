#!/bin/bash
# Shared paths + conda activation for the read-QC steps (3_fastqc.sh, 4_multiqc.sh).
# Source this via $PROJ, NOT via $0 -- SGE copies job scripts to a spool dir, so
# $0 does not point back into this repo.

PROJ="${PROJ:-/u/scratch/d/dlera/annabelle_metagenome/cca-metagenome}"

# The two read sets being compared:
#   minknow -- the original on-instrument basecall, split into ~30-73 chunk
#              files per barcode under fastq_pass/<barcode>/
#   dorado  -- the sup re-basecall + demux from steps 1-2, already collapsed to
#              one fastq.gz per barcode
MINKNOW_DIR="${MINKNOW_DIR:-/u/scratch/d/dlera/annabelle_metagenome/Metagenome/Metagenome_AC/AC_Meta/20260521_1020_MN49060_FBG11764_98045ec5/fastq_pass}"
DORADO_DIR="${DORADO_DIR:-/u/scratch/d/dlera/annabelle_metagenome/basecalled-reads/fastq}"

QC="$PROJ/results/read-qc"
MANIFEST="$QC/manifest.tsv"        # dataset <TAB> barcode <TAB> input dir-or-file
FASTQC_DIR="$QC/fastqc"
MULTIQC_DIR="$QC/multiqc"
LOGS="$PROJ/logs"

CONDA_ENV="${CONDA_ENV:-readqc}"   # holds fastqc 0.12.1 + multiqc 1.35

activate_env() {
    source /u/home/d/dlera/anaconda3/etc/profile.d/conda.sh
    conda activate "$CONDA_ENV"
    # The compute nodes have no UTF-8 locale, which makes FastQC's perl
    # wrapper spew a warning block on every single run.
    export LC_ALL=C
}

mkdir -p "$QC" "$FASTQC_DIR/minknow" "$FASTQC_DIR/dorado" "$MULTIQC_DIR" "$LOGS"
