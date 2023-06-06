params.graffite_vcf   = false
params.vcf            = false
params.RM_vcf         = false // mainly for debug. Requires --RM_dir
params.RM_dir         = false // mainly for debug. Requires --RM_vcf
params.genotype       = true
params.graph_method   = "pangenie" // or giraffe or graphaligner
params.reads          = "reads.csv"
params.longreads      = false // if you want to use sniffles on long read alignments
params.assemblies     = false // if you want to use svim-asm on genome alignments
params.reference      = "reference.fa"
params.TE_library     = "TE_library.fa"
params.out            = "out"
params.tsd_win        = 30 // add default value for TSD window search
params.cores          = false // set to an integer
params.mammal         = false
params.mini_K         = "500M"
params.stSort_m       = "4G"
params.stSort_t       = 4
params.version        = "0.2.3 beta (02-21-2023)"
params.tsd_batch_size = 100
params.asm_divergence = "asm5"

// ideally, we should have defaults relative to genome size
params.svim_asm_memory      = null
params.svim_asm_threads     = 1
params.sniffles_memory      = null
params.sniffles_threads     = 1
params.repeatmasker_memory  = null
params.repeatmasker_threads = 1
params.pangenie_memory      = null
params.pangenie_threads     = 1
params.make_graph_memory    = null
params.make_graph_threads   = 1 
params.graph_align_memory   = null
params.graph_align_theads   = 1
params.vg_call_memory       = null
params.vg_call_threads      = 1
params.min_mapq             = 0
params.min_support          = "2,4"


//adding time directive options for some processes
params.graph_align_time    = "12h"
params.svim_asm_time       = "1h"
params.sniffles_time       = "2h"
params.pangenie_time       = "2h"
params.repeatmasker_time   = "2h"

//adding some memory default
params.tsd_memory          = "10G"
params.merge_vcf_memory    = "10G"

// SAY HELLO

log.info """

▄████  ██▀███   ▄▄▄        █████▒ █████▒██▓▄▄▄█████▓▓█████
██▒ ▀█▒▓██ ▒ ██▒▒████▄    ▓██   ▒▓██           ██▒ ▓▒▓█   ▀
▒██░▄▄▄░▓██ ░▄█ ▒▒██  ▀█▄  ▒████ ░▒████ ░▒██▒▒ ▓██░ ▒░▒███
░▓█  ██▓▒██▀▀█▄  ░██▄▄▄▄██ ░▓█▒  ░░▓█▒  ░░██░░ ▓██▓ ░ ▒▓█  ▄
░▒▓███▀▒░██▓ ▒██▒  █   ▓██▒░▒█░   ░▒█░   ░██░  ▒██▒ ░ ░▒████▒
░▒   ▒ ░ ▒▓ ░▒▓░ ▒▒   ▓▒█░ ▒ ░    ▒ ░   ░▓    ▒ ░░   ░░ ▒░ ░
░   ░   ░▒ ░ ▒░  ▒   ▒▒ ░ ░      ░      ▒ ░    ░     ░ ░  ░
░ ░   ░   ░░   ░   ░   ▒    ░ ░    ░ ░    ▒ ░  ░         ░
░    ░           ░  ░               ░              ░  ░

V . ${params.version}

Find and Genotype Transposable Elements Insertion Polymorphisms
in Genome Assemblies using a Pangenomic Approach

Authors: Cristian Groza and Clément Goubert
Bug/issues: https://github.com/cgroza/GraffiTE/issues

"""

// if user uses global preset for number of cores
if(params.cores) {
repeatmasker_threads = params.cores
svim_asm_threads     = params.cores
pangenie_threads     = params.cores
graph_align_threads  = params.cores
vg_call_threads      = params.cores
sniffles_threads     = params.cores
} else {
repeatmasker_threads = params.repeatmasker_threads
svim_asm_threads     = params.svim_asm_threads
pangenie_threads     = params.pangenie_threads
graph_align_threads  = params.graph_align_threads
vg_call_threads      = params.vg_call_threads
sniffles_threads     = params.sniffles_threads
}


process sniffles_sample_call {
cpus sniffles_threads
memory params.sniffles_memory
time params.sniffles_time
publishDir "${params.out}/1_SV_search/sniffles2_individual_VCFs", mode: 'copy'

input:
set val(sample_name), file(longreads), val(type), file(ref)

output:
file "${sample_name}.snf", emit: sniffles_sample_call_out_ch
file "${sample_name}.vcf"

script:
"""
minimap2 -t ${sniffles_threads} -ax map-${type} ${ref} ${longreads} | samtools sort -m${params.stSort_m} -@${params.stSort_t} -o ${sample_name}.bam  -
  samtools index ${sample_name}.bam
sniffles --minsvlen 100 --threads ${sniffles_threads} --reference ${ref} --input ${sample_name}.bam --snf ${sample_name}.snf --vcf ${sample_name}.vcf
"""
}

process sniffles_population_call {
cpus sniffles_threads
memory params.sniffles_memory
publishDir "${params.out}/1_SV_search", mode: 'copy'

input:
file snfs
file ref

output:
file "*variants.vcf", emit: sn_variants_ch
file "snfs.tsv"

"""
ls *.snf > snfs.tsv
sniffles --minsvlen 100  --threads ${sniffles_threads} --reference ${ref} --input snfs.tsv --vcf genotypes_unfiltered.vcf
bcftools filter -i 'INFO/SVTYPE == "INS" | INFO/SVTYPE == "DEL"' genotypes_unfiltered.vcf | awk '\$5 != "<INS>" && \$5 != "<DEL>"' > sniffles2_variants.vcf
  """
}
process svim_asm {
  cpus svim_asm_threads
  memory params.svim_asm_memory
  time params.svim_asm_time
  publishDir "${params.out}/1_SV_search/svim-asm_individual_VCFs/", mode: 'copy'

  input:
  set val(asm_name), file(asm), file(ref)

  output:
  set val(asm_name), file("${asm_name}.vcf"), emit: svim_out_ch

  script:
  """
  mkdir asm
  minimap2 -a -x ${params.asm_divergence} --cs -r2k -t ${svim_asm_threads} -K ${params.mini_K} ${ref} ${asm} | samtools sort -m${params.stSort_m} -@${params.stSort_t} -o asm/asm.sorted.bam -
    samtools index asm/asm.sorted.bam
  svim-asm haploid --min_sv_size 100 --types INS,DEL --sample ${asm_name} asm/ asm/asm.sorted.bam ${ref}
  sed 's/svim_asm\\./${asm_name}\\.svim_asm\\./g' asm/variants.vcf > ${asm_name}.vcf
  """
}

process survivor_merge {
  cpus svim_asm_threads
  memory params.svim_asm_memory
  publishDir "${params.out}/1_SV_search", mode: 'copy'

  input:
  file(vcfs)

  output:
  file "*variants.vcf", emit: sv_variants_ch
  file "vcfs.txt"

  script:
  """
  ls *.vcf > vcfs.txt
  SURVIVOR merge vcfs.txt 0.1 0 1 0 0 100 svim-asm_variants.vcf
  """
}

process merge_svim_sniffles2 {
  publishDir "${params.out}/1_SV_search", mode: 'copy'

  input:
  file(svim_vcf)
  file(sniffles_vcf)

  output:
  file "svim-sniffles_merged_variants.vcf", emit: sv_sn_variants_ch

  script:
  """
  ls sniffles2_variants.vcf svim-asm_variants.vcf > svim-sniffles2.vcfs.txt
  SURVIVOR merge svim-sniffles2.vcfs.txt 0.1 0 1 0 0 100 svim-sniffles2_merge_genotypes.vcf


  # header part to keep
  HEADERTOP=\$(grep '#' svim-sniffles2_merge_genotypes.vcf | grep -v 'CHROM')
  # modify last header line to fit content
  HEADERLINE=\$(grep '#CHROM' svim-sniffles2_merge_genotypes.vcf | awk '{print \$1"\t"\$2"\t"\$3"\t"\$4"\t"\$5"\t"\$6"\t"\$7"\t"\$8"\tFORMAT\tGT"}')
  # add new info fields
  HEADERMORE=\$(mktemp)
  echo -e '##INFO=<ID=sniffles2_SUPP,Number=1,Type=String,Description="Support vector from sniffle2-population calls">' >> \${HEADERMORE}
  echo -e '##INFO=<ID=sniffles2_SVLEN,Number=1,Type=Integer,Description="SV length as called by sniffles2-population">' >> \${HEADERMORE}
  echo -e '##INFO=<ID=sniffles2_SVTYPE,Number=1,Type=String,Description="Type of SV from sniffle2-population calls">' >> \${HEADERMORE}
  echo -e '##INFO=<ID=sniffles2_ID,Number=1,Type=String,Description="ID from sniffle2-population calls">' >> \${HEADERMORE}
  echo -e '##INFO=<ID=svim-asm_SUPP,Number=1,Type=String,Description="Support vector from svim-asm calls">' >> \${HEADERMORE}
  echo -e '##INFO=<ID=svim-asm_SVLEN,Number=1,Type=Integer,Description="SV length as called by svim-asm">' >> \${HEADERMORE}
  echo -e '##INFO=<ID=svim-asm_SVTYPE,Number=1,Type=String,Description="Type of SV from svim-asm calls">' >> \${HEADERMORE}
  echo -e '##INFO=<ID=svim-asm_ID,Number=1,Type=String,Description="ID from svim-asm calls">' >> \${HEADERMORE}
  # arrange the body part
  BODY=\$(mktemp)
  paste -d ";" <(grep -v '#' svim-sniffles2_merge_genotypes.vcf | \
    cut -f 1-8) <(grep -v '#' svim-sniffles2_merge_genotypes.vcf | \
    cut -f 10 | sed 's/:/\t/g' | \
    awk '{print "sniffles2_SUPP="\$2";sniffles2_SVLEN="\$3";sniffles2_SVTYPE="\$7";sniffles2_ID="\$8}') <(grep -v '#' svim-sniffles2_merge_genotypes.vcf | \
    cut -f 11 | sed 's/:/\t/g' | awk '{print "svim-asm_SUPP="\$2";svim-asm_SVLEN="\$3";svim-asm_SVTYPE="\$7";svim-asm_ID="\$8"\t\\.\t\\."}') >> \${BODY}
  # concatenate and save "variants" file
  cat <(echo "\${HEADERTOP}") \${HEADERMORE} <(echo "\${HEADERLINE}") \${BODY} > svim-sniffles_merged_variants.vcf
  """

}

process repeatmask_VCF {
  cpus repeatmasker_threads
  memory params.repeatmasker_memory
  time params.repeatmasker_time
  publishDir "${params.out}/2_Repeat_Filtering", mode: 'copy'

  input:
  file("genotypes.vcf")
  file(TE_library)
  file(ref_fasta)

  output:
  file("genotypes_repmasked_filtered.vcf"), emit: tsd_ch, tsd_search_ch, tsd_gather_ch
  path("repeatmasker_dir/"), emit: tsd_RM_ch, tsd_search_RM_ch

  script:
  if(params.mammal)
    """
  repmask_vcf.sh genotypes.vcf genotypes_repmasked.vcf.gz ${TE_library} MAM
  bcftools view -G genotypes_repmasked.vcf.gz | \
    awk -v FS='\t' -v OFS='\t' \
    '{if(\$0 ~ /#CHROM/) {\$9 = "FORMAT"; \$10 = "ref"; print \$0} else if(substr(\$0, 1, 1) == "#") {print \$0} else {\$9 = "GT"; \$10 = "1|0"; print \$0}}' | \
    awk 'NR==1{print; print "##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">"} NR!=1' | \
    bcftools view -i 'INFO/total_match_span > 0.80' -o genotypes_repmasked_temp.vcf
  fix_vcf.py --ref ${ref_fasta} --vcf_in genotypes_repmasked_temp.vcf --vcf_out genotypes_repmasked_filtered.vcf
  """
  else
    """
  repmask_vcf.sh genotypes.vcf genotypes_repmasked.vcf.gz ${TE_library}
  bcftools view -G genotypes_repmasked.vcf.gz | \
    awk -v FS='\t' -v OFS='\t' \
    '{if(\$0 ~ /#CHROM/) {\$9 = "FORMAT"; \$10 = "ref"; print \$0} else if(substr(\$0, 1, 1) == "#") {print \$0} else {\$9 = "GT"; \$10 = "1|0"; print \$0}}' | \
    awk 'NR==1{print; print "##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">"} NR!=1' | \
    bcftools view -i 'INFO/total_match_span > 0.80' -o genotypes_repmasked_temp.vcf
  fix_vcf.py --ref ${ref_fasta} --vcf_in genotypes_repmasked_temp.vcf --vcf_out genotypes_repmasked_filtered.vcf
  """
}

process tsd_prep {
  memory params.tsd_memory

  input:
  file("genotypes_repmasked_filtered.vcf")
  path("repeatmasker_dir/*")
  file(ref_fasta)

  output:
  file("indels.txt"), emit: tsd_search_input, tsd_count_input

  file("SV_sequences_L_R_trimmed_WIN.fa"), emit: tsd_search_SV
  file("flanking_sequences.fasta"), emit: tsd_search_flanking

  script:
  """
  cp repeatmasker_dir/repeatmasker_dir/* .
  prepTSD.sh ${ref_fasta} ${params.tsd_win}
  #wc -l indels.txt > indel_len
  """
}

process tsd_report {
  memory params.tsd_memory
  publishDir "${params.out}/3_TSD_search", mode: 'copy'

  input:
  path(x)
  path(y)
  path("genotypes_repmasked_filtered.vcf")

  output:
  path("TSD_summary.txt"), emit: tsd_sum_group_ch
  path("TSD_full_log.txt"), emit: tsd_full_group_ch
  path("pangenome.vcf"), emit: vcf_ch, vcf_merge_ch

  script:
  """
  cat ${x} > TSD_summary.txt
  cat ${y} > TSD_full_log.txt
  join -13 -21 <(grep -v "#" genotypes_repmasked_filtered.vcf | cut -f 1-3 | sort -k3,3) <(grep 'PASS' TSD_summary.txt | awk '{print \$1"\t"\$(NF-2)","\$(NF-1)}' | sort -k1,1) | \
    awk '{print \$2"\t"\$3"\t"\$1"\t"\$4}' | \
    sort -k1,1 -k2,2n > TSD_annotation
  HDR_FILE=\$(mktemp)
  echo -e '##INFO=<ID=TSD,Number=1,Type=String,Description="Target site duplication sequence passing filters">' >> \${HDR_FILE}
  TSD_FILE=TSD_annotation
  bgzip \${TSD_FILE}
  tabix -s1 -b2 -e2 \${TSD_FILE}.gz
  bcftools annotate -a \${TSD_FILE}.gz -h \${HDR_FILE} -c CHROM,POS,~ID,INFO/TSD genotypes_repmasked_filtered.vcf | bcftools view > pangenome.vcf
  """
}

process pangenie {
  cpus pangenie_threads
  memory params.pangenie_memory
  time params.pangenie_time
  publishDir "${params.out}/4_Genotyping", mode: 'copy'

  input:
  set val(sample_name), file(sample_reads), file(vcf), file(ref)

  output:
  file("${sample_name}_genotyping.vcf.gz*"), emit: indexed_vcfs

  script:
  """
  PanGenie -t ${pangenie_threads} -j ${pangenie_threads} -s ${sample_name} -i <(zcat -f ${sample_reads}) -r ${ref} -v ${vcf} -o ${sample_name}
  bgzip ${sample_name}_genotyping.vcf
  tabix -p vcf ${sample_name}_genotyping.vcf.gz
  """
}

process make_graph {
  cpus params.make_graph_threads
  memory params.make_graph_memory
  input:
  file vcf
  file fasta

  output:
  file "index", emit: graph_index_ch, vg_index_call_ch

  script:
  prep = """
  bcftools sort -Oz -o sorted.vcf.gz ${vcf}
  tabix sorted.vcf.gz
  mkdir index
  """
  finish = """
  vg snarls index/${graph} > index/index.pb
  """
  switch(params.graph_method) {
    case "giraffe":
      prep + """
      vg autoindex --tmp-dir \$PWD  -p index/index -w giraffe -v sorted.vcf.gz -r ${fasta}
      """ + finish
      break
    case "graphaligner":
      prep + """
      export TMPDIR=$PWD
      vg construct -a  -r ${fasta} -v ${vcf} -m 1024 > index/index.vg
      """ + finish
      break
  }
}

process graph_align_reads {
  cpus graph_align_threads
  memory params.graph_align_memory
  time params.graph_align_time
  errorStrategy 'finish'

  input:
  set val(sample_name), file(sample_reads), file("index")

  output:
  set val(sample_name), file("${sample_name}.gam"), file("${sample_name}.pack"), emit: aligned_ch

  script:
  pack =  """
  vg pack -x index/${graph} -g ${sample_name}.gam -o ${sample_name}.pack -Q ${params.min_mapq}
  """

  switch(params.graph_method) {
    case "giraffe":
      """
      vg giraffe -t ${graph_align_threads} -Z index/index.giraffe.gbz -m index/index.min -d index/index.dist -i -f ${sample_reads} > ${sample_name}.gam
      """ + pack
      break
    case "graphaligner":
      """
      GraphAligner -t ${graph_align_threads} -x vg -g index/index.vg -f ${sample_reads} -a ${sample_name}.gam
      """ + pack
      break
  }
}

process vg_call {
  cpus vg_call_threads
  memory params.vg_call_memory

  input:
  set val(sample_name), file(gam), file(pack), file("index")

  output:
  file("${sample_name}.vcf.gz*"), emit: indexed_vcfs

  script:
  """
  vg call -a -m ${params.min_support} -r index/index.pb -s ${sample_name} -k ${pack} index/${graph} > ${sample_name}.vcf
  bgzip ${sample_name}.vcf
  tabix ${sample_name}.vcf.gz
  """
}

process merge_VCFs {
  memory params.merge_vcf_memory
  publishDir "${params.out}/4_Genotyping", mode: 'copy', glob: 'GraffiTE.merged.genotypes.vcf'

  input:
  file vcfFiles
  path pangenome_vcf

  output:
  file "GraffiTE.merged.genotypes.vcf", emit: typeref_outputs

  script:
  """
  ls *vcf.gz > vcf.list
  bcftools merge -l vcf.list > GraffiTE.merged.genotypes.vcf
  bgzip GraffiTE.merged.genotypes.vcf
  tabix -p vcf GraffiTE.merged.genotypes.vcf.gz
  grep '#' ${pangenome_vcf} > P_header
  grep -v '#' ${pangenome_vcf} | sort -k1,1 -k2,2n > P_sorted_body
  cat P_header P_sorted_body > pangenome.sorted.vcf
  bgzip pangenome.sorted.vcf
  tabix -p vcf pangenome.sorted.vcf.gz
  bcftools annotate -a pangenome.sorted.vcf.gz -c CHROM,POS,ID,INFO GraffiTE.merged.genotypes.vcf.gz > GraffiTE.merged.genotypes.vcf
  """
}

workflow {
  // initiate channels that will provide the reference genome to processes
  Channel.fromPath(params.reference).into{ref_geno_ch;
                                          ref_asm_ch;
                                          ref_sniffles_sample_call_ch;
                                          ref_sniffles_population_call_ch;
                                          ref_repeatmasker_ch;
                                          ref_tsd_ch;
                                          ref_tsd_search_ch}

  if(!params.graffite_vcf && !params.vcf && !params.RM_vcf) {
    if(params.longreads) {
      Channel.fromPath(params.longreads).splitCsv(header:true).map{row ->
        [row.sample, file(row.path, checkIfExists:true), row.type]}.combine(ref_sniffles_sample_call_ch).set{sniffles_sample_call_in_ch}

      sniffles_sample_call(sniffles_sample_call_in_ch)
      sniffles_population_call(sniffles_sample_call.sniffles_sample_call_out_ch.collect(),
                               ref_sniffles_population_call_ch)
    }
    if(params.assemblies) {
      Channel.fromPath(params.assemblies).splitCsv(header:true).map{row ->
        [row.sample, file(row.path, checkIfExists:true)]}.combine(ref_asm_ch).set{svim_in_ch}
      svim_asm(svim_in_ch)
      survivor_merge(svim_asm.svim_out_ch.map{sample -> sample[1]}.collect())
    }

    if(params.assemblies && params.longreads) {
      merge_svim_sniffles2(survivor_merge.sv_variants_ch, sniffles_population_call.sn_variants_ch)
    }
  }
}
