#!/bin/bash
#$ -cwd
#$ -pe threaded 12
#$ -o logs
#$ -j y
#$ -l h_vmem=2G
#$ -V

trap "exit 100" ERR

set -e -o pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename $0) <IN file> <OUT file>"
    exit 1
fi

IN=$1
OUT=$2

printf -- "[$(date)] Start vep.sh for $IN -> ${OUT}.\n---\n"

eval "$(conda shell.bash hook)"
conda activate --no-stack vep

vep -i $IN -o $OUT -e --cache --offline --fork $((NSLOTS-2)) --pick --force_overwrite --tab

conda deactivate

printf -- "---\n[$(date)] Finish vep.sh\n"

