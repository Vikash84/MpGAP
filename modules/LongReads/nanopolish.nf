process nanopolish {
  publishDir "${params.outdir}/longreads-only/nanopolish_polished_contigs/${assembler}", mode: 'copy', overwrite: true
  container 'fmalmeida/mpgap'
  cpus params.threads

  input:
  tuple file(draft), val(lrID), val(assembler)
  file reads
  file fast5
  val fast5_dir

  output:
  tuple file("${assembler}_${lrID}_nanopolished.fa"), val(lrID), val("${assembler}-nanopolish") // Save nanopolished contigs
  file "${assembler}_${lrID}_nanopolished.complete.vcf" // Save VCF

  script:
  """
  source activate NANOPOLISH ;
  zcat -f ${reads} > reads ;
  if [ \$(grep -c "^@" reads) -gt 0 ] ; then sed -n '1~4s/^@/>/p;2~4p' reads > reads.fa ; else mv reads reads.fa ; fi ;
  nanopolish index -d "${fast5_dir}" reads.fa ;
  minimap2 -d draft.mmi ${draft} ;
  minimap2 -ax map-ont -t ${params.threads} ${draft} reads.fa | samtools sort -o reads.sorted.bam -T reads.tmp ;
  samtools index reads.sorted.bam ;
  python /miniconda/envs/NANOPOLISH/bin/nanopolish_makerange.py ${draft} | parallel --results nanopolish.results -P ${params.cpus} \
  nanopolish variants --consensus -o polished.{1}.vcf \
    -w {1} \
    -r reads.fa \
    -b reads.sorted.bam \
    -g ${draft} \
    --max-haplotypes ${params.nanopolish_max_haplotypes} \
    --min-candidate-frequency 0.1;
  nanopolish vcf2fasta --skip-checks -g ${draft} polished.*.vcf > ${assembler}_${lrID}_nanopolished.fa ;
  cat polished.*.vcf >> ${assembler}_${lrID}_nanopolished.complete.vcf
  """
}
