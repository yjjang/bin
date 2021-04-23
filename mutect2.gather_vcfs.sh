#!/bin/bash
#$ -cwd
#$ -l h_vmem=16G

trap "exit 100" ERR

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename $0) <pair> <out dir> <chrs> <toolinfo>"
    exit 1
fi

PAIR=$1
OUTDIR=$2
CHRS="$3"
TOOLINFO=$4
source $TOOLINFO

set -eu -o pipefail

DONE=$OUTDIR/run_status/$PAIR.mutect2.GatherVcf.done

CHR_RAW_VCFS=""
for CHR in ${CHRS//:/ }; do CHR_RAW_VCFS="$CHR_RAW_VCFS -I $OUTDIR/$PAIR.$CHR.raw.vcf.gz"; done
CHR_VCFS=""
for CHR in ${CHRS//:/ }; do CHR_VCFS="$CHR_VCFS -I $OUTDIR/$PAIR.$CHR.vcf.gz"; done
RAW_VCF=$OUTDIR/$PAIR.mutect2.raw.vcf.gz
VCF=${RAW_VCF/.raw.vcf.gz/.vcf.gz}

printf -- "---\n[$(date)] Start concat vcfs: $PAIR.\n"

if [[ -f $DONE ]]; then
    echo "Skip this step."
else
    $GATK4 --java-options "-Xmx4G" GatherVcfs -R $REF_GENOME $CHR_RAW_VCFS -O $RAW_VCF
    $GATK4 --java-options "-Xmx4G" GatherVcfs -R $REF_GENOME $CHR_VCFS -O $VCF

    for CHR in ${CHRS//:/ }; do
        rm -f $OUTDIR/$PAIR.$CHR.raw.vcf.gz
        rm -f $OUTDIR/$PAIR.$CHR.raw.vcf.gz.tbi
        rm -f $OUTDIR/$PAIR.$CHR.raw.vcf.gz.stats
        rm -f $OUTDIR/$PAIR.$CHR.vcf.gz
        rm -f $OUTDIR/$PAIR.$CHR.vcf.gz.tbi
        rm -f $OUTDIR/$PAIR.$CHR.vcf.gz.filteringStats.tsv
        rm -f $OUTDIR/intervals_$CHR.bed
    done

    $BCFTOOLS index -t $RAW_VCF
    $BCFTOOLS index -t $VCF
    touch $DONE
fi

rm -rf $OUTDIR/tmp

printf -- "[$(date)] Finish concat vcfs.\n---\n"
