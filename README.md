# 2021_kga0_4dn-mouse-cross

### KA Allele Segregation Pipeline

This pipeline is used to segregate sci-ATAC-seq alignments to parental alleles of origin based on alignment scores.

## News and Updates
* 2022-03-20
  + add 05-lift-strain-to-mm10.sh
  + add script to download and process liftOver chain files: get-liftOver-chains.sh
  + add script to downsample bam files: generate-downsampled-bam.sh
  + minor changes to workflow scripts 01 and 04
  + update `README`, including sample-call section

* 2022-03-19
  + update workflow image.
  + update readme for (filter reads with MAPQ < 30; then removing singleton; subread repair).
  + update code for (filter reads with MAPQ < 30; then removing singleton; subread repair.).

* 2022-03-17
  + add new workflow image.
  + CX updated get_unique_fragments.py. Kris will test it on duplicates.
  + After Shendure lab pipeline, we will first filter reads with MAPQ < 30; then removing singleton; (Kris: no need to sort anymore) subread repair. 

* `#TODO` list
  + add workflow image.
  + add `README` file (describe the flow, add example code to run).
  + create workflow folder.

## Installation

`#TODO` Need to add later.

`#TODO` Need to add version numbers. `TODO` Need to include additional dependencies.
  + R
  + Rsamtools
  + liftOver
  + subread
  + samtools
  + BBMap
  + parallel

## Workflow

![plot](AlleleSegregation-03-19-2022.png)

The user needs to run the following steps to prepare the input for KA's pipeline:
1. Demux. ([Example Code 1](https://github.com/Noble-Lab/2021_kga0_4dn-mouse-cross/blob/main/bin/workflow/01-demux.sh))
2. sci-ATAC-seq analysis pipeline from the Shendure Lab. ([Example Code 2](https://github.com/Noble-Lab/2021_kga0_4dn-mouse-cross/blob/main/bin/workflow/02-sci-ATAC-seq-analysis.sh))
3. Preprocess the bam. ([Example Code 3](https://github.com/Noble-Lab/2021_kga0_4dn-mouse-cross/blob/main/bin/workflow/03-preprocess.sh))
    + filter reads with MAPQ < 30; 
    + then remove singleton; 
    + subread repair.
4. Split the bam file by chromosome. Index and "repair" the split bam files. Generate bed files from the split bam files. ([Example Code 4](https://github.com/Noble-Lab/2021_kga0_4dn-mouse-cross/blob/main/bin/workflow/04-split-index-repair-bam.sh))
5. Perform liftOvers of the bed files. ([Example Code 5](https://github.com/Noble-Lab/2021_kga0_4dn-mouse-cross/blob/main/bin/workflow/05-lift-strain-to-mm10.sh))

This pipeline takes as input two bam files (strain 1 assembly and strain 2 assembly) that have been sorted, subject to duplicate removal, and outputs a 3D tensor: (Cell, Allele, Category), where Category can be one of the ["paternal","maternal","ambiguous"].

1. liftOver to mm10.
2. Allele score comparison.

Here, we use downsampled mm10/CAST data as an example:

### 1. Split bam infile by chromosome; index and "repair" split bam files; and then generate bed files for needed for liftOver

```{bash split-index-repair-bam}
#  Call script from the repo's home directory, 2021_kga0_4dn-mouse-cross
safe_mode="FALSE"
infile="./data/files_bam_test/test.300000.bam"
outpath="./data/2022-0320_test_04-05_all"
chromosome="all"
repair="TRUE"
bed="TRUE"
parallelize=4

bash bin/workflow/04-split-index-repair-bam.sh \
-u "${safe_mode}" \
-i "${infile}" \
-o "${outpath}" \
-c "${chromosome}" \
-r "${repair}" \
-b "${bed}" \
-p "${parallelize}"

#  Run time: 11 seconds

# -h <print this help message and exit>
# -u <use safe mode: "TRUE" or "FALSE" (logical)>
# -i <bam infile, including path (chr)>
# -o <path for split bam file(s) and bed files (chr); path will be
#     made if it does not exist>
# -c <chromosome(s) to split out (chr); for example, "chr1" for
#     chromosome 1, "chrX" for chromosome X, "all" for all
#     chromosomes>
# -r <use Subread repair on split bam files: "TRUE" or "FALSE"
#     (logical)>
# -b <if "-r TRUE", create bed files from split bam files: "TRUE"
#     or "FALSE" (logical); argument "-b" only needed when "-r
#     TRUE">
# -p <number of cores for parallelization (int >= 1)>
```

### 2. Lift coordinates over from the initial alignment-strain coordinates (e.g., "CAST-EiJ" coordinates) to "mm10" coordinates

```{bash liftover}
#  Call script from the repo's home directory, 2021_kga0_4dn-mouse-cross
#  Requirement: GNU Parallel should be in your "${PATH}"; install it if not
safe_mode="FALSE"
infile="$(find "./data/2022-0320_test_04-05_all" -name "*.*os.bed" | sort -n)"
outpath="./data/2022-0320_test_04-05_all"
strain="CAST-EiJ"
chain="./data/files_chain/CAST-EiJ-to-mm10.over.chain.gz"

parallel --header : -k -j 4 \
"bash ./bin/workflow/05-lift-strain-to-mm10.sh \
-u {safe_mode} \
-i {infile} \
-o {outpath} \
-s {strain} \
-c {chain}" \
::: safe_mode "${safe_mode}" \
::: infile "${infile[@]}" \
::: outpath "${outpath}" \
::: strain "${strain}" \
::: chain "${chain}"

#  Run time: 119 seconds

# -h <print this help message and exit>
# -u <use safe mode: "TRUE" or "FALSE" (logical)>
# -i <bed infile, including path (chr)>
# -o <path for "lifted" bed outfiles (chr)>
# -s <strain for performing liftOver of bed files; currently available
#     options:
#     - "CAST-EiJ", "CAST", or "C" for "CAST-EiJ"
#     - "129S1-SvImJ", "129", or "1" for "129S1-SvImJ"
#     - "CAROLI-EiJ", "CAROLI", "Ryukyu" or "R" for "CAROLI-EiJ"
#     - "SPRET-EiJ", "SPRET", or "S" for "SPRET-EiJ>"
# -c <gzipped liftOver chain file for strain, including path (chr);
#     note: for liftOver to work, the liftOver strain chain should
#     match the strain set in argument "-s">
```

### 3. Allele-assignment based on alignment scores
`#TODO #INPROGRESS`

```{R liftover}
R CMD 05-AS.R?
```
