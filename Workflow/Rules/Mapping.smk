# Authors v1.0 (Legacy):    ..., ..., ... & ...
# Authors v2.0 (New):       Jelle van der Heide
# Date:                     ../../..
# 
# This file contains rules for mapping with multiple different mappers. Currently, three options have 
# been defined. All three mappers require an indexation step prior to their execution. By adjusting 
# the [mapper_mode] option in the config-file, users can choose whether a specific mapper should be 
# used (Bowtie2, BWA or STAR) or if all three should be executed in the same run.
# --------------------------------------------------------------------------------------------------------------------


# This rule handles the indexing of the meta-reference file according to the way the Bowtie mapper expects
# it to be indexed. Additionally, as this is the start of the mapping process, a timestamp is written to a
# file for realtime benchmarking purposes. 
# -----     
# Input:    - The de-novo assembled meta-reference file.
# Output:   - An undisclosed number of index files, depending on reference size.
rule mapping_Bowtie2_index:
    params: 
        indexprefix=expand("{map_index_dir}/Bowtie/index", map_index_dir=config["map_index_dir"])
    input: 
        refblasted=expand("{blasting_out}/Eukaryota_ref.fa",blasting_out=config["blasting_out"])
    output:
        index=expand("{map_index_dir}/Bowtie/index.1.bt2", map_index_dir=config["map_index_dir"])
    log:
        out="../Logs/Mapping/mapping_bowtie2_index.out.log", 
        err="../Logs/Mapping/mapping_bowtie2_index.err.log"
    benchmark:
        "../Benchmarks/mapping_Bowtie2_index.benchmark.tsv"
    conda: 
        "../Envs/bowtie2.yaml"
    threads: 
        32
    shell:
        """
        echo "Commencing Bowtie mapping" >> time.txt
        date +%s%N >> time.txt
        bowtie2-build \
            -f {input.refblasted} \
            {params.indexprefix} \
            -p {threads} \
            > {log.out} \
            2> {log.err}
        """

# This rule executes a Bowtie mapping process, by mapping all preprocessed reads (this includes the
# reads that make up the meta-reference) on the de-novo assembled meta-reference. This requires 
# an undisclosed number of index files generated by the previous rule. 
# [NOTE] The current implementation is not set up for multimapping for benchmarking purposes.
#        To allow for multimapping, the parameter "-k 10" should be added to the shell block.
# -----
# Input:    - All index-files created by the previous rule.
#           - Both preprocessed read-files from one of the samples.
# Output:   - A sam-file containing an alignment for all reads from one of the samples on the meta-reference.
#           - A bam-file containing an alignment for all reads from one of the samples on the meta-reference.
#             [NOTE] this file does NOT have any readgroups just yet.
rule mapping_Bowtie2:   
    params:
        sample='{sample}',
        indexprefix=expand("{map_index_dir}/Bowtie/index", map_index_dir=config["map_index_dir"])
    input:
        index=expand("{map_index_dir}/Bowtie/index.1.bt2", map_index_dir=config["map_index_dir"]),
        r1=expand("{readgrouped_dir}/{{sample}}.1.fq.gz",readgrouped_dir=config["readgrouped_dir"]),
        r2=expand("{readgrouped_dir}/{{sample}}.1.fq.gz",readgrouped_dir=config["readgrouped_dir"])
    output:
        samOut=temp(expand("{sam_dir}/Bowtie/mapping_sq_{{sample}}.sam",sam_dir=config["sam_dir"])),
        bamOut=temp(expand("{bam_dir}/Bowtie/mapping_sq_{{sample}}.bam",bam_dir=config["bam_dir"]))
    log: 
        bowtie2="../Logs/Mapping/mapping_bowtie2_{sample}_bt.log",
        samtools="../Logs/Mapping/mapping_bowtie2_{sample}_st.log"
    benchmark:
        "../Benchmarks/mapping_Bowtie2_{sample}.benchmark.tsv"
    conda: 
        "../Envs/bowtie2.yaml"
    threads: 
        8
    shell:
        """
        bowtie2 \
            -x {params.indexprefix} \
            -1 {input.r1} \
            -2 {input.r2} \
            -q \
            --end-to-end \
            --very-fast \
            --threads {threads} \
            -S {output.samOut} \
            2> {log.bowtie2}
        samtools view \
            -b \
            -o {output.bamOut} {output.samOut} \
            2> {log.samtools}
        """


# This rule handles the indexing of the meta-reference file according to the way the Bwa mapper expects
# it to be indexed. Additionally, as this is the start of the mapping process, a timestamp is written to a
# file for realtime benchmarking purposes. 
# -----     
# Input:    - The de-novo assembled meta-reference file.
# Output:   - An undisclosed number of index files, depending on reference size.
rule mapping_bwa_index:
    params: 
        indexprefix=expand("{map_index_dir}/Bwa", map_index_dir=config["map_index_dir"])
    input: 
        refblasted=expand("{blasting_out}/Eukaryota_ref.fa",blasting_out=config["blasting_out"])
    output:
        index=expand("{map_index_dir}/Bwa/index.amb", map_index_dir=config["map_index_dir"])
    log: 
        "../Logs/Mapping/mapping_bwa_index.log"
    benchmark:
        "../Benchmarks/mapping_BWA_index.benchmark.tsv"
    conda: 
        "../Envs/bwa.yaml"
    threads: 
        32
    shell:
        """
        echo "Commencing Bwa mapping" >> time.txt
        date +%s%N >> time.txt
        bwa index \
            -p {params.indexprefix}/index \
            {input.refblasted} \
            2> {log}
        """

# This rule executes a Bwa mapping process, by mapping all preprocessed reads (this includes the
# reads that make up the meta-reference) on the de-novo assembled meta-reference. This requires 
# an undisclosed number of index files generated by the previous rule. 
# [NOTE] The current implementation is not set up for multimapping for benchmarking purposes.
#        To allow for multimapping, the parameter "-c 10" should be added to the shell block.
# -----         
# Input:    - All index-files created by the previous rule.
#           - Both preprocessed read-files from one of the samples.
# Output:   - A sam-file containing an alignment for all reads from one of the samples on the meta-reference.
#             A bam-file containing an alignment for all reads from one of the samples on the meta-reference.
#             [NOTE] this file does NOT have any readgroups just yet.
rule mapping_BWA:
    params:
        sample='{sample}',
        indexprefix=expand("{map_index_dir}/Bwa/index", map_index_dir=config["map_index_dir"])
    input:
        index=expand("{map_index_dir}/Bwa/index.amb", map_index_dir=config["map_index_dir"]),
        r1=expand("{readgrouped_dir}/{{sample}}.1.fq.gz",readgrouped_dir=config["readgrouped_dir"]),
        r2=expand("{readgrouped_dir}/{{sample}}.1.fq.gz",readgrouped_dir=config["readgrouped_dir"])
    output:
        samOut=temp(expand("{sam_dir}/Bwa/mapping_sq_{{sample}}.sam",sam_dir=config["sam_dir"])),
        bamOut=temp(expand("{bam_dir}/Bwa/mapping_sq_{{sample}}.bam",bam_dir=config["bam_dir"]))
    log: 
        bwa="../Logs/Mapping/mapping_bwa_{sample}_bw.log",
        samtools="../Logs/Mapping/mapping_bwa_{sample}_st.log"
    benchmark:
        "../Benchmarks/mapping_BWA_{sample}.benchmark.tsv"
    conda: 
        "../Envs/bwa.yaml"
    threads: 
        8
    shell:
        """
        bwa mem \
            -t {threads} \
            -R '@RG\\tID:{params.sample}\\tSM:{params.sample}' \
            {params.indexprefix} \
            {input.r1} \
            {input.r2} \
            > {output.samOut} \
            2> {log.bwa}
        samtools view \
            -b \
            -o {output.bamOut} {output.samOut} \
            2> {log.samtools}
        """

# This rule handles the indexing of the meta-reference file according to the way the Star mapper expects
# it to be indexed. Additionally, as this is the start of the mapping process, a timestamp is written to a
# file for realtime benchmarking purposes. 
# -----     
# Input:    - The de-novo assembled meta-reference file.
# Output:   - An undisclosed number of index files, depending on reference size.
rule mapping_star_index:
    params:
        indexprefix=expand("{map_index_dir}/Star", map_index_dir=config["map_index_dir"]),
        indextemp=expand("../Misc/Mapping/Indexed/Star")
    input:
        refblasted=expand("{blasting_out}/Eukaryota_ref.fa",blasting_out=config["blasting_out"])
    output:
        genome=expand("{map_index_dir}/Star/Genome" , map_index_dir=config["map_index_dir"])
    log: 
        "../Logs/Mapping/mapping_star_index.log"
    benchmark: 
        "../Benchmarks/mapping_star_index.benchmark.tsv"
    conda: 
        "../Envs/star.yaml"
    threads: 
        32
    shell:
        """
        echo "Commencing STAR mapping" >> time.txt
        date +%s%N >> time.txt
        STAR \
            --genomeSAindexNbases 10 \
            --runThreadN {threads} \
            --runMode genomeGenerate \
            --genomeDir {params.indexprefix} \
            --genomeFastaFiles {input.refblasted} \
            --outTmpDir {params.indextemp} \
            --limitGenomeGenerateRAM 72476175285 \
            2> {log}
        """

# This rule executes a Star mapping process, by mapping all preprocessed reads (this includes the
# reads that make up the meta-reference) on the de-novo assembled meta-reference. This requires 
# an undisclosed number of index files generated by the previous rule. 
# -----     
# Input:    - All index-files created by the previous rule.
#           - Both preprocessed read-files from one of the samples.
# Output:   - A sam-file containing an alignment for all reads from one of the samples on the meta-reference.
#             A bam-file containing an alignment for all reads from one of the samples on the meta-reference.
#             [NOTE] this file does NOT have any readgroups just yet.
rule mapping_Star:
    params:
        sample='{sample}',
        indexprefix=expand("{map_index_dir}/Star", map_index_dir=config["map_index_dir"]),
        r1out=expand("{readgrouped_dir}/{{sample}}.1.fq",readgrouped_dir=config["readgrouped_dir"]),
        r2out=expand("{readgrouped_dir}/{{sample}}.2.fq",readgrouped_dir=config["readgrouped_dir"])
    input:
        genome=expand("{map_index_dir}/Star/Genome" , map_index_dir=config["map_index_dir"]),
        r1=expand("{readgrouped_dir}/{{sample}}.1.fq.gz",readgrouped_dir=config["readgrouped_dir"]),
        r2=expand("{readgrouped_dir}/{{sample}}.2.fq.gz",readgrouped_dir=config["readgrouped_dir"])
    output:        
        samOut=temp(expand("{sam_dir}/Star/mapping_sq_{{sample}}.sam",sam_dir=config["sam_dir"])),
        bamOut=temp(expand("{bam_dir}/Star/mapping_sq_{{sample}}.bam",bam_dir=config["bam_dir"]))
    log: 
        star="../Logs/Mapping/mapping_star_{sample}_st.log",
        samtools="../Logs/Mapping/mapping_star_{sample}_st.log"
    benchmark: 
        "../Benchmarks/mapping_star_{sample}.benchmark.tsv"
    conda: 
        "../Envs/star.yaml"
    threads: 
        8
    shell:
        """
        gunzip -f {input.r1}
        gunzip -f {input.r2}
        STAR \
            runThreadN {threads} \
            --genomeDir {params.indexprefix} \
            --readFilesIn {params.r1out} {params.r2out} \
            --outSAMattributes NM MD AS \
            --outSAMtype SAM \
            --outFileNamePrefix ../Output/Mapping/{params.sample}_ \
            --outFilterMatchNminOverLread 0.95 \
            --clip3pNbases 1 1 \
            --outSAMorder PairedKeepInputOrder \
            --outFilterMultimapScoreRange 0 \
            --alignEndsType Extend5pOfRead1 \
            --scoreGapNoncan 0 \
            --scoreGapGCAG 0 \
            --scoreGapATAC 0 \
            --scoreDelOpen 0 \
            --scoreDelBase 0 \
            --scoreInsOpen 0 \
            --scoreInsBase 0 \
            --alignMatesGapMax 20 \
            --readMapNumber \
            -1 2> {log.star}
        mv ../Output/Mapping/{params.sample}_Aligned.out.sam {output.samOut}
        samtools view -b -o {output.bamOut} {output.samOut} \
            2> {log.samtools}
        gzip -f {params.r1out}
        gzip -f {params.r2out}
        """
