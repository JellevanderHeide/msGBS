rule mapping:
    params:
        tmpdirthis=tmpdirthis,
        inputdir=expand("{path}/output_denovo",  path=config["output_dir"]),
        outputdir=expand("{path}/mapping",  path=config["output_dir"]),
        barcodes=expand("{path}/{bar}", path=config["input_dir"], bar=config["barcode_filename"]),
    input:
        refBlasted=expand("{path}/output_denovo/refBlasted.fa",path=config["output_dir"]),
        joined_All=expand("{path}/output_denovo/all.joined.fastq.gz",  path=config["output_dir"]),
        merged_All=expand("{path}/output_denovo/all.merged.fastq.gz",  path=config["output_dir"])
    output:
        log=expand("{path}/mapping/mapping_variantcalling.log",path=config["output_dir"]),
        bamOut=expand("{path}/mapping/out.bam",path=config["output_dir"])
    threads: 40
    shell:
        "python src/scripts/Map_STAR_snake.py --tmpdir {params.tmpdirthis} "
        "--input_dir {params.inputdir} "
        "--output_dir {params.outputdir} "
        "--threads {threads} "
        "--barcodes {params.barcodes}"

rule stats:
    input:
        bamOut=expand("{path}/mapping/out.bam",path=config["output_dir"])
    output:
        statscsv=expand("{path}/stats/stats.csv",path=config["output_dir"])
    shell:
        "python src/scripts/msGBS_STATS.py "
        "-i {input.bamOut} "
        "-o {output.statscsv}"
