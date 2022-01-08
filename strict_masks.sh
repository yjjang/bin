#!/bin/bash
#$ -cwd
#$ -pe threaded 16
#$ -o logs
#$ -j y
#$ -l h_vmem=1G
#$ -V

trap "exit 100" ERR
set -e -o pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <BED file>"
    exit 1
fi

INFILE=$1
OUTFILE=${INFILE%.*}.masks.${INFILE##*.}

STRICT_MASK=/home/mayo/m216456/Apps/bsmn-pipeline/resources/hg19/20141020.strict_mask.whole_genome.fasta.gz

if [ -z $NSLOTS ]; then NSLOTS=$(nproc); fi
NPROC=$((NSLOTS-2))
NLINE=$(($(grep -v ^# $INFILE | wc -l)/$(($NPROC-1))))
if [[ $NLINE -lt 1 ]]; then NLINE=1; fi

printf -- "[$(date)] Annotate regions with 1000G strict mask info.\n---\n"
SECONDS=0

echo "[INFO] INPUT: $INFILE"
echo "[INFO] OUTPUT: $OUTFILE"
echo "[INFO] $NPROC processors; $NLINE lines per one processor"

annotate() {
    local STRICT_MASK=$1
    cut -f1-3 \
    |while read -r CHR START END; do
         MASKS=`samtools faidx $STRICT_MASK ${CHR/chr/}:$START-$END |tail -n +2 |paste -sd ''`
         echo -e "$CHR\t$START\t$END\t$MASKS"
     done
}
export -f annotate

grep -v ^# $INFILE \
|parallel --pipe -N $NLINE -j $NPROC annotate $STRICT_MASK \
|awk -v OFS='\t' \
     'NR==FNR {
          ann[$1, $2, $3] = $4
          next
      } {
          if ($1 ~ /^#/) print $0
          else print $0, ann[$1, $2, $3]
      }' - $INFILE \
>$OUTFILE


printf -- "---\n[$(date)] Done.\n"

elapsed=$SECONDS
printf -- "\nTotal $(($elapsed / 3600)) hours, $(($elapsed % 3600 / 60)) minutes and $(($elapsed % 60)) seconds elapsed."

