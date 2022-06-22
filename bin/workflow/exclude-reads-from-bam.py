#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Apr 26 17:56:44 2022.

@author: kalavattam
"""

from __future__ import division, absolute_import, print_function
import argparse
import gzip
import os
import pysam
import subprocess
from tqdm import tqdm


def count_reads(bam):
    """
    Call samtools to return the number of reads in a bam file.

    Parameters
    ----------
    bam : str
        bam infile, including path
    """
    count = subprocess.check_output(
        ["samtools view -c " + bam],
        shell=True
    ).decode("utf-8").rstrip("\n")
    return count


def get_final_bam_qname(bam):
    """
    Call samtools to return the QNAME of the final read in a bam file.

    Parameters
    ----------
    bam : str
        bam infile, including path
    """
    qname = subprocess.check_output(
        ["samtools view " + bam + " | tail -1 | cut -f1"],
        shell=True
    ).decode("utf-8").rstrip("\n")
    return qname


def detect_filetype_from_path(file):
    """
    Determine file type (bam, sam, txt, txt.gz) based on extension.

    Parameters
    ----------
    file : str
        infile, including path
    """
    #  Convert to lowercase for simpler comparisons
    file = file.lower()

    #  Parse sam, bam, txt, txt.gz file extensions
    if file.endswith('.sam'):
        return 'sam'
    elif file.endswith('.bam'):
        return 'bam'
    elif file.endswith('.txt'):
        return 'txt'
    elif file.endswith('.txt.gz'):
        return 'txt.gz'
    else:
        return None


def write_alignment(alignment, outfile=None):
    """
    Print alignment to outfile or, if none is supplied, STDOUT .

    Parameters
    ----------
    alignment : pysam.AlignedSegment
        alignment to be written to bam outfile

    outfile: str
        outfile

    """
    if outfile is None:
        print(alignment)
    else:
        outfile.write(alignment)


def generate_bam_by_excluding_qnames(infile, qnames, outfile=None):
    """
    Filter out reads in a sam/bamfile based on QNAME.

    Parameters
    ----------
    infile : str
        QNAME-sorted bam file, including path

    qnames : str
        text file containing QNAME(s) to exclude, including path

    outfile : str
        bam outfile, including path
    """
    #  Read in QNAME-sorted bam file
    bam = pysam.AlignmentFile(infile, "rb")

    #  Set up outfile
    file_type = detect_filetype_from_path(outfile)
    if file_type is None:
        outfile = None
    elif file_type == 'sam':
        outfile = pysam.AlignmentFile(outfile, "w", template=bam)
    elif file_type == 'bam':
        outfile = pysam.AlignmentFile(outfile, "wb", template=bam)
    else:
        raise ValueError(
            "Unknown format for `outfile`: {}".format(outfile)
        )

    # Evaluate QNAME file, read in QNAMEs to be removed, then sort QNAMEs to
    # match BAM for efficient processing
    file_type = detect_filetype_from_path(qnames)
    if file_type == 'qnames':
        ids = list(set(
            [i.rstrip() for i in open(qnames, "r").readlines()]
        ))
        ids.sort(key=str.lower, reverse=True)
    elif file_type == 'txt.gz':
        ids = list(set(
            [i.decode().rstrip() for i in gzip.open(qnames, "r").readlines()]
        ))
        ids.sort(key=str.lower, reverse=True)  # Sort in reverse
    else:
        raise ValueError("Unknown format for `qnames`: {}".format(qnames))
    n_ids = len(ids)

    #  Set up progress bar that draws on total alignment counts
    pbar = tqdm()

    #  Set up and assign variables needed in while loop
    reads = bam.fetch(until_eof=True)
    read = next(reads)
    last_list_qname = ids[0]
    last_bam_qname = get_final_bam_qname(infile)

    #  If first read QNAME is greater than last list QNAME, throw error
    if read.query_name > last_list_qname:
        raise ValueError(
            "Alignment file appears to be unsorted: {} > {}".
            format(read.query_name, last_list_qname)
        )

    #  If first read QNAME is greater than last bam QNAME, throw error
    if read.query_name > last_bam_qname:
        raise ValueError(
            "Alignment file appears to be unsorted: {} > {}".
            format(read.query_name, last_bam_qname)
        )

    #  Generate bam outfile by exlcuding reads in list from bam infile
    while True:
        #  If bam QNAME equals last list QNAME in stack, break while loop
        if read.query_name == last_list_qname:
            break
        #  If bam QNAME is greater than list QNAME
        if read.query_name > ids[-1]:
            #  Test if list QNAME is last in stack; if so, write remaining
            #  reads, then break while loop
            if n_ids == 1:
                outfile.write(read)
                for r in bam:
                    outfile.write(read)
                break
            #  ...otherwise, pop list QNAME from stack and try again
            else:
                ids.pop()
                n_ids -= 1
        #  Skip bam reads that match list QNAMEs (at top of stack)
        elif read.query_name == ids[-1]:
            #  If bam QNAME is final bam QNAME, break
            if read.query_name == last_bam_qname:
                break
            #  ...otherwise, move on to next read
            else:
                read = next(reads)
        #  If bam QNAME is less than top of stack, write read and move on
        else:
            #  If reach final list QNAME, handle any extra bam QNAMEs
            if n_ids == 1:
                outfile.write(read)
                #  If bam QNAME is final bam QNAME, write and break
                if read.query_name == last_bam_qname:
                    read = next(reads)
                    outfile.write(read)
                    break
                #  ...otherwise, move on to next read
                else:
                    read = next(reads)
            #  ...otherwise, write and move on to next read
            else:
                outfile.write(read)
                read = next(reads)
        pbar.update()
    outfile.close()


def main():
    """
    #TODO Some description of the script.

    Parameters
    ----------
    #TODO Some description of the parameters.
    """
    ap = argparse.ArgumentParser(
        description="""
        Filter bam infile to exclude reads based on list of QNAMEs (supplied in
        txt file); write to bam outfile or STDOUT.
        """,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    ap.add_argument(
        "-i",
        "--bam_in",
        type=str,
        help="QNAME-sorted bam infile to be filtered, including path"
    )
    ap.add_argument(
        "-q",
        "--qnames",
        type=str,
        help="text infile containing QNAMEs to be excluded, including path"
    )
    ap.add_argument(
        "-o",
        "--bam_out",
        type=str,
        help="bam outfile, including path"
    )

    #  Parse arguments
    arguments = ap.parse_args()
    bam_in = arguments.bam_in
    bam_out = arguments.bam_out
    bam_out_name = arguments.bam_out
    qnames = arguments.qnames

    print("\n")
    print("Started: Processing **" + os.path.basename(bam_in) + "**")
    print(" - Excluding reads in **" + os.path.basename(qnames) + "**")
    print(" - Will generate **" + os.path.basename(bam_out) + "**")

    generate_bam_by_excluding_qnames(bam_in, qnames, bam_out)
    count = count_reads(bam_out_name)

    print("Completed: Processing **" + os.path.basename(bam_in) + "**")
    print(" - Generated **" + os.path.basename(bam_out) + "**")
    print(" - Number of records in outfile: " + count)


main()


# os.chdir("/Users/kalavattam/Dropbox/UW/projects-etc/2021_kga0_4dn-mouse-cross")
# os.getcwd()

# path_main = "./data/files_bam_test/"
# # path_CAST = path_main + "CAST/"
# path_mm10 = path_main + "mm10/"

# infile = path_CAST + "Disteche_sample_11.dedup.corrected.corrected.downsample-6000000.queryname.bam"
# qnames = path_main + "Disteche_sample_11.CAST-and-mm10.combined.sorted.duplicated.txt.gz"  # CAST.ambiguous
# outfile = path_main + "python.Disteche_sample_11.dedup.corrected.corrected.downsample-6000000.CAST.ambiguous.bam"

# infile = path_CAST + "Disteche_sample_11.dedup.corrected.corrected.downsample-6000000.queryname.bam"
# qnames = path_main + "Disteche_sample_11.ambiguous-and-CAST.combined.sorted.txt.gz"  # CAST.mm10
# outfile = path_main + "python.Disteche_sample_11.dedup.corrected.corrected.downsample-6000000.CAST.mm10.bam"

# infile = path_CAST + "Disteche_sample_11.dedup.corrected.corrected.downsample-6000000.queryname.bam"
# qnames = path_main + "Disteche_sample_11.ambiguous-and-mm10.combined.sorted.txt.gz"  # CAST.CAST
# outfile = path_main + "python.Disteche_sample_11.dedup.corrected.corrected.downsample-6000000.CAST.CAST.bam"

# infile = path_mm10 + "Disteche_sample_11.dedup.corrected.corrected.downsample-6000000.queryname.bam"
# qnames = path_main + "Disteche_sample_11.CAST-and-mm10.combined.sorted.duplicated.txt.gz"  # mm10.ambiguous
# outfile = path_main + "python.Disteche_sample_11.dedup.corrected.corrected.downsample-6000000.mm10.ambiguous.bam"

# infile = path_mm10 + "Disteche_sample_11.dedup.corrected.corrected.downsample-6000000.queryname.bam"
# qnames = path_main + "Disteche_sample_11.ambiguous-and-CAST.combined.sorted.txt.gz"  # mm10.mm10
# outfile = path_main + "python.Disteche_sample_11.dedup.corrected.corrected.downsample-6000000.mm10.mm10.bam"

# infile = path_mm10 + "Disteche_sample_11.dedup.corrected.corrected.downsample-6000000.queryname.bam"
# qnames = path_main + "Disteche_sample_11.ambiguous-and-mm10.combined.sorted.txt.gz"  # mm10.CAST
# outfile = path_main + "python.Disteche_sample_11.dedup.corrected.corrected.downsample-6000000.mm10.CAST.bam"

# os.path.isfile(infile)
# os.path.isfile(qnames)
