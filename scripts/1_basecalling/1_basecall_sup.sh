#!/bin/bash
#$ -cwd
#$ -N ac_meta_sup
#$ -o basecall_sup.$JOB_ID.log
#$ -j y
#$ -M dlera@mail
#$ -m bea
# NOTE: GPU type / count / walltime are supplied by submit.sh on the qsub command
# line, because they differ per GPU flavour. Do not hard-code -l gpu here.

set -u

DORADO=/u/scratch/d/dlera/software/bin/dorado
MODELS=/u/scratch/d/dlera/software/dorado-models
MODEL=dna_r10.4.1_e8.2_400bps_sup@v5.2.0
KIT=SQK-NBD114-24
POD5=/u/scratch/d/dlera/annabelle_metagenome/Metagenome/Metagenome_AC/AC_Meta/20260521_1020_MN49060_FBG11764_98045ec5/pod5
OUTDIR=/u/scratch/d/dlera/annabelle_metagenome/basecalled-reads
OUT=$OUTDIR/AC_Meta_sup_v5.2.0.bam
DEMUX=$OUTDIR/demux

echo "=== $(date) ==="
echo "node      : $(hostname)"
echo "model     : $MODEL"
echo "kit       : $KIT"
echo "pod5 dir  : $POD5  ($(ls "$POD5"/*.pod5 | wc -l) files)"
nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-<unset>}"

# Address only the GPUs SGE actually granted us. SGE on this cluster does NOT
# reliably confine a job to its granted GPUs -- a cuda=1 job can still see all
# devices on the node -- so "cuda:all" would happily trample a co-tenant's job.
# If CUDA_VISIBLE_DEVICES is set the set is already renumbered and cuda:all is
# correct; otherwise pick the NGPU idlest devices ourselves by memory in use.
NGPU=${NGPU:-1}
if [ -n "${CUDA_VISIBLE_DEVICES:-}" ]; then
    DEVICE=cuda:all
else
    IDLE=$(nvidia-smi --query-gpu=index,memory.used --format=csv,noheader,nounits \
           | sort -t, -k2 -n | head -n "$NGPU" | cut -d, -f1 | paste -sd,)
    if [ -z "$IDLE" ]; then
        echo "could not enumerate GPUs" >&2; exit 1
    fi
    DEVICE="cuda:$IDLE"
fi
echo "device    : $DEVICE  (NGPU=$NGPU)"

# ---------------------------------------------------------------- basecall ----
# --kit-name classifies AND trims barcodes in the same pass, writing BC tags.
# Resume an earlier run that hit the walltime cap: dorado re-reads the partial
# BAM and skips reads already called.
RESUME=""
if [ -s "$OUT" ]; then
    PARTIAL=$OUTDIR/AC_Meta_sup_v5.2.0.partial.$(date +%s).bam
    echo "found existing output, resuming from $PARTIAL"
    mv "$OUT" "$PARTIAL"
    RESUME="--resume-from $PARTIAL"
fi

$DORADO basecaller "$MODEL" "$POD5" \
    --models-directory "$MODELS" \
    --device "$DEVICE" \
    --kit-name "$KIT" \
    --recursive \
    $RESUME \
    > "$OUT"
RC=$?
echo "basecaller exit: $RC"
[ $RC -ne 0 ] && exit $RC
ls -lh "$OUT"

# ------------------------------------------------------------------- demux ----
# --no-classify reuses the BC tags written above instead of re-classifying,
# so this is just a split and takes minutes, not hours.
echo "=== demux $(date) ==="
rm -rf "$DEMUX"; mkdir -p "$DEMUX"
$DORADO demux --no-classify --output-dir "$DEMUX" "$OUT"
RC=$?
echo "demux exit: $RC"
[ $RC -ne 0 ] && exit $RC

# ----------------------------------------------------------------- summary ----
echo "=== summary $(date) ==="
$DORADO summary "$OUT" > "$OUTDIR/AC_Meta_sup_v5.2.0.summary.tsv" 2>/dev/null
# dorado writes a MinKNOW-style tree: <exp>/<sample>/<run>/bam_pass/<barcode>/*.bam
source /u/local/Modules/default/init/bash
module load samtools/1.15
echo "--- reads per barcode ---"
for d in $(find "$DEMUX" -type d -name 'barcode*' -o -type d -name 'unclassified' | sort); do
    n=0
    for b in "$d"/*.bam; do
        [ -e "$b" ] || continue
        n=$(( n + $(samtools view -c "$b") ))
    done
    printf "%-14s %-6s %10d\n" "$(basename "$d")" "$(basename "$(dirname "$d")")" "$n"
done
echo "--- demux tree ---"
find "$DEMUX" -name '*.bam' | wc -l | xargs echo "bam files written:"
du -sh "$DEMUX"
echo "=== done $(date) ==="
