#!/bin/bash
#$ -cwd

trap "exit 100" ERR

if [[ $# -lt 7 ]]; then
    echo "Usage: $(basename $0) <normal sample> <normal bam> <tumor sample> <tumor bam> <out dir> <chrs> <toolinfo> <BED file>"
    exit 1
fi

NSM=$1
NBAM=$2
TSM=$3
TBAM=$4
OUTDIR=$5
CHR=$(echo $6 |cut -f${SGE_TASK_ID} -d ':')
TOOLINFO=$7
source $TOOLINFO
BED=$8
if [ -z $BED ]; then
    INTERVALS=$CHR
else
    INTERVALS=$OUTDIR/intervals_$CHR.bed
    grep -w ^$CHR $BED > $INTERVALS
fi
if [ -z "$MUTECT2_PARAMS" ]; then MUTECT2_PARAMS=""; fi


set -eu -o pipefail

DONE1=$OUTDIR/run_status/${NSM}_${TSM}.Mutect2.$CHR.done
DONE2=$OUTDIR/run_status/${NSM}_${TSM}.FilterMutectCalls.$CHR.done

CHR_RAW_VCF=$OUTDIR/${NSM}_${TSM}.$CHR.raw.vcf.gz
CHR_VCF=${CHR_RAW_VCF/.raw.vcf.gz/.vcf.gz}

printf -- "---\n[$(date)] Start Mutect2 calling: $NSM - $TSM, $CHR\n"

if [[ -f $DONE1 ]]; then
    echo "Skip the Mutect2 calling."
else
    $GATK4 --java-options "-Xmx25G -Djava.io.tmpdir=$OUTDIR/tmp -XX:-UseParallelGC" Mutect2 \
        -R $REF_GENOME \
        -I $TBAM\
        -I $NBAM\
        -normal $NSM \
        -L $INTERVALS \
        -O $CHR_RAW_VCF \
        $MUTECT2_PARAMS
    touch $DONE1
fi

if [ ! -z $BED ]; then rm $INTERVALS; fi

printf -- "[$(date)] Finish Mutect2: $NSM - $TSM, $CHR\n---\n"

printf -- "---\n[$(date)] Start FilterMutectCalls: $NSM - $TSM, $CHR\n"

if [[ -f $DONE2 ]]; then
    echo "Skip the FilterMutectCalls."
else
    $GATK4 --java-options "-Xmx25G -Djava.io.tmpdir=$OUTDIR/tmp -XX:-UseParallelGC" \
        FilterMutectCalls -V $CHR_RAW_VCF -O $CHR_VCF -R $REF_GENOME
    touch $DONE2
fi

printf -- "[$(date)] Finish FilterMutectCalls: $NSM - $TSM, $CHR\n---\n"
