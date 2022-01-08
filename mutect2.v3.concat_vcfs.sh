#!/bin/bash
#$ -cwd
#$ -pe threaded 1
#$ -j y
#$ -l h_vmem=4G

trap "exit 100" ERR

if [[ $# -lt 3 ]]; then
    echo "Usage: $(basename $0) <mutect2 out dir> <chrs> <tools_info.txt>"
    false
fi

OUTDIR=$1
CHRS=$2
PAIR=$(basename $OUTDIR)

TOOLINFO=$3
source $TOOLINFO

printf -- "---\n[$(date)] Start making the final VCF file at $1.\n"

zcat $OUTDIR/$PAIR.$(echo $CHRS |cut -f1 -d ' ').mutect2.v3.vcf.gz |grep "^#" > $OUTDIR/tmp.vcf
zcat $OUTDIR/$PAIR.*.mutect2.v3.vcf.gz |grep -v "^#" |sort -k1,1V -k2,2n >> $OUTDIR/tmp.vcf
$BCFTOOLS/bcftools view -O z -o $OUTDIR/$PAIR.mutect2.vcf.gz $OUTDIR/tmp.vcf
$BCFTOOLS/bcftools index -t $OUTDIR/$PAIR.mutect2.vcf.gz
rm $OUTDIR/tmp.vcf
rm $OUTDIR/$PAIR.*.mutect2.v3.vcf.{gz,gz.tbi,idx}
rm -f $OUTDIR/intervals_*.bed
rm -rf $OUTDIR/temp

printf -- "---\n[$(date)] Finished the final VCF file.\n"
