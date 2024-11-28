
# merget mono readparen als dit mogelijk is. wat niet kan worden gemerget komt in joined_1 en 2
rule merge_mono:
    params:
        sample='{sample}',
        inputdir=expand("{path}/Preprocessing/monos",  path=config["output_dir"]),
        outputdir=expand("{path}/output_denovo/",  path=config["output_dir"]),
        preprosup=expand("{preprosup}", preprosup=config["preprocessingsup_dir"])
    input:
        R1_in=expand("{path}/Preprocessing/monos/{sample}.demultiplexed_R1.fq.gz",  path=config["output_dir"],sample=MONOS),
        R2_in=expand("{path}/Preprocessing/monos/{sample}.demultiplexed_R2.fq.gz",  path=config["output_dir"],sample=MONOS)
    output:
        unAssembled_1=(expand("{path}/output_denovo/monos/{{sample}}.joined_1.fastq.gz",  path=config["output_dir"])),
        unAssembled_2=(expand("{path}/output_denovo/monos/{{sample}}.joined_2.fastq.gz",  path=config["output_dir"])),
        merged_Assembled=(expand("{path}/output_denovo/monos/{{sample}}.merged.fastq.gz",  path=config["output_dir"]))
    threads: 1
    log: "../Logs/Reference_creation/merge_mono_{sample}.log"
    conda: "../Envs/merge_reads.yaml"
    shell:
        "NGmerge -1 {params.inputdir}/{params.sample}.demultiplexed_R1.fq.gz "
        "-2 {params.inputdir}/{params.sample}.demultiplexed_R2.fq.gz "
        "-o {params.outputdir}/monos/{params.sample}.merged.fastq.gz -n {threads} "
        "-f {params.outputdir}/monos/{params.sample}.joined "
        "-w {params.preprosup}/qual_profile.txt -q 33 -u 41 -z -g 2> {log}"


#joint de overgebleven readparen. dit komt in een volledig joined.fastq.gz bestand per mono
rule combine_joined:
    params:
        sample='{sample}',
        inputdir=expand("{path}/output_denovo/monos",  path=config["output_dir"]),
        cycles=getParam_cycle(param_cycle)
    input:
        unAssembled_1=expand("{path}/output_denovo/monos/{sample}.joined_1.fastq.gz",path=config["output_dir"],sample=MONOS),
        unAssembled_2=expand("{path}/output_denovo/monos/{sample}.joined_2.fastq.gz",path=config["output_dir"],sample=MONOS),
        barcodes=expand("{path}/{bar}", path=config["input_dir"], bar=config["barcode_filename"])
    #log:
    output:
        joined_combined=(expand("{path}/output_denovo/monos/{{sample}}.joined.fastq.gz",  path=config["output_dir"]))
    conda: "../Envs/combine_reads.yaml"
    shell:
        """
        header=$(awk 'NR==1 {{print; exit}}' {input.barcodes})
        IFS="	"; headerList=($header)
        set +u
        for ((i=1; i<=${{#headerList[@]}}; i++)); do
            case "${{headerList[$i]}}" in
                Barcode_R1)
                    BR1i="$i"
                    ;;
                Barcode_R2)
                    BR2i="$i"
                    ;;
                Wobble_R1)
                    WR1i="$i"
                    ;;
                Wobble_R2)
                    WR2i="$i"
                    ;;
            esac
        done

        BR1MaxLen=0
        BR2MaxLen=0
        WR1Max=0
        WR2Max=0

        {{
            read
            while read line; do
                ifs="	"; thisLine=($line)
                if [ ${{thisLine[WR1i]}} -gt $WR1Max ]; then
                    WR1Max=${{thisLine[WR1i]}}
                fi
                if [ ${{thisLine[WR2i]}} -gt $WR2Max ]; then
                    WR2Max=${{thisLine[WR2i]}}
                fi
                if [ ${{#thisLine[BR1i]}} -gt $BR1MaxLen ]; then
                    BR1MaxLen=${{#thisLine[BR1i]}}
                fi
                if [ ${{#thisLine[BR2i]}} -gt $BR2MaxLen ]; then
                    BR2MaxLen=${{#thisLine[BR2i]}}
                fi
            done
        }} < {input.barcodes}

        maxR1=$((cycles - BR1MaxLen - WR1Max))
        maxR2=$((cycles - BR2MaxLen - WR2Max))
        paste <(seqtk seq {input.unAssembled_1} | cut -c1-141) <(seqtk seq -r {input.unAssembled_2} | cut -c1-141 | seqtk seq -r -) | cut -f1-5 | sed $'/^@/!s/\t/NNNNNNNN/g' | sed s/+NNNNNNNN+/+/g | sed $'s/ /\t/' | cut -f1,2 | pigz -p 1 -c > {output.joined_combined}
        """ # dit is een deel dezelfde code als barcode zooi in de prepro 
        # maxbc len kan in snakefile. bash kan dit niet blijkbaar

# plak de merged en joined reads per mono aan elkaar in een bestand
rule cat_monos:
    params:
        sample='{sample}',
        inputdir=expand("{path}/output_denovo/monos",  path=config["output_dir"])
    input:
        joined_combined=expand("{path}/output_denovo/monos/{{sample}}.joined.fastq.gz",  path=config["output_dir"]),
        merged_Assembled=expand("{path}/output_denovo/monos/{{sample}}.merged.fastq.gz",  path=config["output_dir"])
    output:
        monoFA=(expand("{path}/output_denovo/monos/{{sample}}.combined.fastq.gz",  path=config["output_dir"]))
    shell:
        """
        cat {input.joined_combined} {input.merged_Assembled} > {params.inputdir}/{params.sample}.combined.fastq.gz
        """

rule sort:
    params:
        sample='{sample}',
        inputdir=expand("{path}/output_denovo/monos",  path=config["output_dir"])
    input:
        monoFA=expand("{path}/output_denovo/monos/{{sample}}.combined.fastq.gz",  path=config["output_dir"])
    output:
        derep=(expand("{path}/output_denovo/monos/{{sample}}.sorted.fa",  path=config["output_dir"])),
    log: "../Logs/Reference_creation/sort_{sample}.log"
    conda: "../Envs/sort.yaml"
    shell:
        """
        vsearch -sortbylength {params.inputdir}/{params.sample}.combined.fastq.gz --output {params.inputdir}/{params.sample}.sorted.fa 2> {log}
        """


rule sort_2:
    params:
        sample='{sample}',
        inputdir=expand("{path}/output_denovo/monos",  path=config["output_dir"])
    input:
        derep=expand("{path}/output_denovo/monos/{sample}.derep.fa",  path=config["output_dir"],sample=MONOS)
    output:
        derep=(expand("{path}/output_denovo/monos/{{sample}}.ordered.fa",  path=config["output_dir"]))
    conda: "../Envs/sort.yaml"
    log: "../Logs/Reference_creation/sort_2_{sample}.log"
    shell:
         "vsearch -sortbylength {params.inputdir}/{params.sample}.derep.fa "
         "--output {params.inputdir}/{params.sample}.ordered.fa 2> {log}"

rule derep:  #misschien is deze nu overbodig geworden
    params:
        sample='{sample}',
        inputdir=expand("{path}/output_denovo/monos",  path=config["output_dir"]),
        minSize=getParam_mind(param_mind)
    input:
        monoFA=expand("{path}/output_denovo/monos/{sample}.sorted.fa",  path=config["output_dir"],sample=MONOS)
    output:
        derep=(expand("{path}/output_denovo/monos/{{sample}}.derep.fa",  path=config["output_dir"]))
    conda: "../Envs/derep.yaml"
    log: "../Logs/Reference_creation/derep_{sample}.log"
    shell:
         "vsearch -derep_fulllength {params.inputdir}/{params.sample}.sorted.fa "
         "-sizeout -minuniquesize {params.minSize}  -output {params.inputdir}/{params.sample}.derep.fa 2> {log}"

rule cluster:
    params:
        sample='{sample}',
        inputdir=expand("{path}/output_denovo/monos",  path=config["output_dir"]),
        minSize=getParam_mind(param_mind)
    input:
        monoFA=expand("{path}/output_denovo/monos/{sample}.ordered.fa",  path=config["output_dir"],sample=MONOS),
    output:
        derep=expand("{path}/output_denovo/monos/{{sample}}.clustered.fa",  path=config["output_dir"])
    threads: 1
    conda: "../Envs/cluster.yaml"
    log: "../Logs/Reference_creation/sluster{sample}.log"
    shell:
         "vsearch -cluster_smallmem {params.inputdir}/{params.sample}.ordered.fa -id 0.95 "
         "-centroids {params.inputdir}/{params.sample}.clustered.fa -sizeout -strand both --threads {threads} 2> {log}"

rule rename_fast:
    params:
        sample='{sample}',
        inputdir=expand("{path}/output_denovo/monos",  path=config["output_dir"]),
        minSize=getParam_mind(param_mind)
    input:
        monoFA=expand("{path}/output_denovo/monos/{sample}.clustered.fa",  path=config["output_dir"],sample=MONOS),
    output:
        derep=(expand("{path}/output_denovo/monos/{{sample}}.renamed.fa",  path=config["output_dir"]))
    shell: 
        """
        number=""
        keep=FALSE

        if [ {params.sample} = "chr" ];
        then
            genotype={params.sample}
        elif [ {params.sample} ]; 
        then
            genotype="{params.sample}""_"
        else 
            genotype=""
        fi
        if [ $number ]; 
        then
            index=0
        elif [ $keep ]; 
        then
            index=1
        fi
        while read line; do
            #if [[ "$line" =~ ^>.* ]]; then
            if [[ $line == \>* ]]; then
                index=$((index+1))
                echo -e ">$genotype$index" >> {params.inputdir}/{params.sample}.renamed.fa
            elif [[ "$line" =~ ^@.* ]]
            then
                if [ !$index ];
                then
                    index=$((index+1))
                else 
                    echo
                    # splits de regel op '#' en pak hier de 0de positie van
                    # splits bovenstaande op ':' en pak hier de [1:-1] waarde van
                    # plak de stukken die hier uit resulteren aan elkaar met een ':' er tussen
                fi

                if [[ "$line" =~ "^@.*/[12]?\n$" ]];
                then
                    end=${{line:-2}} 
                else 
                    end=""
                fi
                echo -e "@$genotype$index$end" >> {params.inputdir}/{params.sample}.renamed.fa
            elif [[ "$line" =~ ^+.* ]]
            then
                echo -e "+$genotype$index$end" >> {params.inputdir}/{params.sample}.renamed.fa
            else
                echo "$line" >> {params.inputdir}/{params.sample}.renamed.fa
            fi
        done < {params.inputdir}/{params.sample}.clustered.fa
        """ # hier is een bepaalde mogelijkheid van de flow nog niet uitgewerkt. de data waar ik mee werk komt hier 
                #niet toe, maar moet nog wel worden gedaan.

rule ref_out:
    input:
        monoFA=expand("{path}/output_denovo/monos/{sample}.renamed.fa",  path=config["output_dir"],sample=MONOS)
    output:
        ref=(expand("{path}/output_denovo/ref.fa",path=config["output_dir"]))
    params:
        inputdir=expand("{path}/output_denovo/",  path=config["output_dir"])
    shell:
        "cat {params.inputdir}/monos/*.renamed.fa > {output.ref}"