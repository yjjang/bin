#!/bin/bash
#$ -cwd
#$ -pe threaded 1

trap "exit 100" ERR

if [[ $# -lt 5 ]]; then
    echo "Usage: $(basename $0) <sample name> <sample list file> <out dir> <chrs> <toolinfo> <BED file>"
    false
fi

SM=$1
SMF=$2
OUTDIR=$3
CHR=$(echo "$4" |cut -f${SGE_TASK_ID} -d ':')
TOOLINFO=$5
source $TOOLINFO
BED=$6
if [ -z $BED ]; then
    INTERVALS=$CHR
else
    INTERVALS=$OUTDIR/intervals_$CHR.bed
    grep -w ^$CHR $BED > $INTERVALS
fi
if [ -z "$MUTECT2_PARAMS" ]; then MUTECT2_PARAMS=""; fi

set -eu -o pipefail

DONE1=$OUTDIR/run_status/$SM.Mutect2.$CHR.done
DONE2=$OUTDIR/run_status/$SM.FilterMutectCalls.$CHR.done

IN=$(awk -v S=$SM '$1==S {print $2}' $SMF |sed 's/^/-I /')
CHR_RAW_VCF=$OUTDIR/$SM.$CHR.raw.vcf.gz
CHR_VCF=${CHR_RAW_VCF/.raw.vcf.gz/.vcf.gz}

printf -- "---\n[$(date)] Start Mutect2 calling: $SM, $CHR\n"

if [[ -f $DONE1 ]]; then
    echo "Skip the Mutect2 calling."
else
    $GATK4 --java-options "-Xmx12G -Djava.io.tmpdir=$OUTDIR/tmp -XX:-UseParallelGC" Mutect2 \
        -R $REF_GENOME \
        $IN \
        -L $INTERVALS \
        -O $CHR_RAW_VCF \
        --germline-resource $GNOMAD_SITES \
        --native-pair-hmm-threads $NSLOTS \
        $MUTECT2_PARAMS
    touch $DONE1
fi

printf -- "[$(date)] Finish Mutect2: $SM, chr$CHR\n---\n"

printf -- "---\n[$(date)] Start FilterMutectCalls: $SM, $CHR\n"

if [[ -f $DONE2 ]]; then
    echo "Skip the FilterMutectCalls."
else
    $GATK4 --java-options "-Xmx12G -Djava.io.tmpdir=$OUTDIR/tmp -XX:-UseParallelGC" \
        FilterMutectCalls -V $CHR_RAW_VCF -O $CHR_VCF -R $REF_GENOME
    touch $DONE2
fi

printf -- "[$(date)] Finish FilterMutectCalls: $SM, $CHR\n---\n"
