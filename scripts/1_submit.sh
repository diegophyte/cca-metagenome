#!/bin/bash
# Submit the sup basecalling + demux job to a chosen GPU flavour.
#   ./submit.sh H200     (preferred)
#   ./submit.sh L40S
#   ./submit.sh A100
#
# Resource sizing note: the GPU nodes here are memory-saturated (several have
# <3G free), and h_data is PER SLOT. Keep the slots x h_data product small or
# the job will never schedule no matter how many GPUs are idle.
set -eu
cd "$(dirname "$0")"

GPU=${1:-H200}
case "$GPU" in
    H200) NGPU=${2:-1}; SLOTS=8; MEM=4G; RT=24:00:00 ;;
    L40S) NGPU=${2:-2}; SLOTS=8; MEM=4G; RT=24:00:00 ;;
    A100) NGPU=${2:-1}; SLOTS=6; MEM=4G; RT=24:00:00 ;;
    *) echo "usage: $0 {H200|L40S|A100}" >&2; exit 1 ;;
esac

echo "submitting to $GPU: cuda=$NGPU, $SLOTS slots x $MEM = $(( ${SLOTS} * ${MEM%G} ))G, h_rt=$RT"
qsub -R y -v NGPU="$NGPU" -l "gpu,$GPU,cuda=$NGPU,h_rt=$RT,h_data=$MEM" \
     -pe shared $SLOTS \
     basecall_sup.sh
