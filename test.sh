#!/bin/bash
 set -x
 echo "Testing..."

  mkdir test && cd test
  
  echo "Downloading a reference..."
  curl -L "https://www.ebi.ac.uk/ena/data/view/CP016627.1&display=fasta&download=fasta&filename=entry.fasta" > ref.fa
  
  echo "Downloading some fastq data..."
  ACCESSION="SRR3980470"
  URL=ftp://ftp.sra.ebi.ac.uk/vol1/fastq/${ACCESSION:0:6}/00${ACCESSION:9:10}/${ACCESSION}/
  
  mkdir -p ${ACCESSION}
  wget -O ${ACCESSION}/${ACCESSION}_R1.fastq.gz "${URL}*1*"
  wget -O ${ACCESSION}/${ACCESSION}_R2.fastq.gz "${URL}*2*"
  
  echo "TESTING seqtk..."
  seqtk sample -s100  ${ACCESSION}/${ACCESSION}_R1.fastq.gz 10000 > sub1.fq
  seqtk sample -s100  ${ACCESSION}/${ACCESSION}_R2.fastq.gz 10000 > sub2.fq
  
  [ -f "sub1.fq" ] && \
    echo "seqtk... PASS" || \
   ( echo "seqtk... FAIL" && exit 1 )

  
  echo "TESTING BWA and SAMTOOLS"
  bwa index ref.fa
  bwa mem ref.fa *.fq | samtools view -b | samtools sort -o reads.bam -
  
  [ -f "reads.bam" ] && \
    echo "bwa and samtools... PASS" || \
    ( echo "bwa or samtools... FAIL" && exit 1 )
  
  echo "TESTING bcftools"
  bcftools mpileup -Ou -f ref.fa reads.bam | \
  bcftools call -Ou -mv | \
  bcftools filter -s LowQual -e '%QUAL<20 || DP>100' > var.flt.vcf
  
  [ -f "var.flt.vcf" ] && \
    echo "bcftools... PASS" || \
    ( echo "bcftools... FAIL" && exit 1 )
  
  echo "TESTING minimap2"
  minimap2 -x sr -a ref.fa *.fq | samtools view -b | samtools sort - > reads2.bam
  
  [ -f "reads2.bam" ] && \
    echo "minimap2... PASS" || \
    ( echo "minimap2... FAIL" && exit 1 )
  
  cd ..
  
  rm -rf test
  
  echo "All tests successful..."
  
