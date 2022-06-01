#!/bin/bash

#  remove-duplicate-qnames-AS-HPC-gangliuw.sh
#  KA


time_start="$(date +%s)"


#  Source functions into environment ------------------------------------------
# shellcheck disable=1091
if [[ -f "./bin/auxiliary/functions-preprocessing-HPC.sh" ]]; then
    . ./bin/auxiliary/functions-preprocessing-HPC.sh ||
        {
            echo "Exiting: Unable to source 'functions-preprocessing-HPC.sh'."
            exit 1
        }

    . ./bin/auxiliary/functions-in-progress.sh ||
        {
            echo "Exiting: Unable to source 'functions-preprocessing-HPC.sh'."
            exit 1
        }
elif [[ -f "./functions-preprocessing-HPC.sh" ]]; then
    . ./functions-preprocessing-HPC.sh ||
        {
            echo "Exiting: Unable to source 'functions-preprocessing-HPC.sh'."
            exit 1
        }

    . ./functions-in-progress.sh ||
        {
            echo "Exiting: Unable to source 'functions-in-progress.sh'."
            exit 1
        }
fi


#  Handle arguments, assign variables -----------------------------------------
print_usage() {
    echo ""
    echo "${0}:"
    echo "Run pipeline to filter duplicate QNAMEs from AS.txt.gz file."
    echo "  - Step 01: Copy files of interest to \${TMPDIR}."
    echo "  - Step 02: Identify and write out QNAMEs with more than one entry."
    echo "  - Step 03: Retain only the QNAME column in the outlist."
    echo "  - Step 04: Using the duplicate QNAME outlist, filter the AS.txt.gz file."
    echo "  - Step 05: Count lines in files (infile, outfiles; optional)."
    echo "  - Step 06: Tally entries in files (infile, outfiles; optional)."
    echo "  - Step 07: Create master list of unique QNAMEs."
    echo "  - Step 08: Move outfiles from \${TMPDIR} to \${outpath}."
    echo ""
    echo ""
    echo "Dependencies:"
    echo "  - ..."
    echo ""
    echo ""
    echo "Arguments:"
    echo "-h print this help message and exit"
    echo "-u use safe mode: \"TRUE\" or \"FALSE\" (logical)"
    echo "-i AS.txt.gz infile, including path (chr)"
    echo "-o path for outfiles (chr); path will be made if it does not exist"
    echo "-c count lines: \"TRUE\" or \"FALSE\" (logical)"
    echo "-t tally entries: \"TRUE\" or \"FALSE\" (logical)"
    echo "-r remove intermediate files: \"TRUE\" or \"FALSE\" (logical)"
    exit
}


while getopts "h:u:i:o:c:t:r:" opt; do
    case "${opt}" in
        h) print_usage ;;
        u) safe_mode="${OPTARG}" ;;
        i) infile="${OPTARG}" ;;
        o) outpath="${OPTARG}" ;;
        c) count="${OPTARG}" ;;
        t) tally="${OPTARG}" ;;
        r) remove="${OPTARG}" ;;
        *) print_usage ;;
    esac
done

[[ -z "${safe_mode}" ]] && print_usage
[[ -z "${infile}" ]] && print_usage
[[ -z "${outpath}" ]] && print_usage
[[ -z "${count}" ]] && print_usage
[[ -z "${tally}" ]] && print_usage
[[ -z "${remove}" ]] && print_usage


#  Check variable assignments -------------------------------------------------
echo -e ""
echo -e "Running ${0}... "

#  Evaluate "${safe_mode}"
case "$(echo "${safe_mode}" | tr '[:upper:]' '[:lower:]')" in
    true | t) echo -e "-u: Safe mode is TRUE." && set -Eeuxo pipefail ;;
    false | f) echo -e "-u: Safe mode is FALSE." ;;
    *) \
        echo -e "Exiting: -u safe mode argument must be \"TRUE\" or \"FALSE\".\n"
        exit 1
        ;;
esac

#  Check that "${infile}" exists
[[ -f "${infile}" ]] ||
    {
        echo -e "Exiting: -i ${infile} does not exist.\n"
        exit 1
    }

#  Make "${outpath}" if it doesn't exist
[[ -d "${outpath}" ]] ||
    {
        echo -e "-o: Directory ${outpath} does not exist; making the directory."
        mkdir -p "${outpath}"
    }

#  Evaluate "${tally}"
case "$(echo "${tally}" | tr '[:upper:]' '[:lower:]')" in
    true | t) \
        tally=1
        echo -e "-t: \"Tally entries\" is TRUE."
        ;;
    false | f) \
        tally=0
        echo -e "-t: \"Tally entries\" is FALSE."
        ;;
    *) \
        echo -e "Exiting: -t \"tally entries\" argument must be \"TRUE\" or \"FALSE\".\n"
        exit 1
        ;;
esac

#  Evaluate "${count}"
case "$(echo "${count}" | tr '[:upper:]' '[:lower:]')" in
    true | t) \
        count=1
        echo -e "-c: \"Count lines\" is TRUE."
        ;;
    false | f) \
        count=0
        echo -e "-c: \"Count lines\" is FALSE."
        ;;
    *) \
        echo -e "Exiting: -c \"count lines\" argument must be \"TRUE\" or \"FALSE\".\n"
        exit 1
        ;;
esac

#  Evaluate "${remove}"
case "$(echo "${remove}" | tr '[:upper:]' '[:lower:]')" in
    true | t) \
        remove=1
        echo -e "-r: Remove intermediate files is TRUE."
        ;;
    false | f) \
        remove=0
        echo -e "-r: Remove intermediate files is FALSE."
        ;;
    *) \
        echo -e "Exiting: -r remove intermediate files must be \"TRUE\" or \"FALSE\".\n"
        exit 1
        ;;
esac

echo ""


#  Assign variables needed for the pipeline -----------------------------------
# infile="Disteche_sample_1.dedup.CAST.corrected.CAST.AS.txt.gz"
# outpath="$(pwd)"
# tmp="${outpath}/${infile}"

base="$(basename "${infile}")"
tmp="${TMPDIR}/${base}"
tmp_tally="${tmp/.txt.gz/.tally.txt.gz}"
tmp_tally_gt_1="${tmp/.txt.gz/.tally-gt-1.txt.gz}"
cut="${tmp/.txt.gz/.cut.txt.gz}"
corrected="${tmp/.txt.gz/.corrected.txt.gz}"
corrected_tally="${corrected/.txt.gz/.tally.txt.gz}"

#  Assign variables for completion files
step_1="$(echo_completion_file "${outpath}" 1 "${infile%.gz}")"
step_2="$(echo_completion_file "${outpath}" 2 "${infile%.gz}")"
step_3="$(echo_completion_file "${outpath}" 3 "${infile%.gz}")"
step_4="$(echo_completion_file "${outpath}" 4 "${infile%.gz}")"
step_5="$(echo_completion_file "${outpath}" 5 "${infile%.gz}")"
step_6="$(echo_completion_file "${outpath}" 6 "${infile%.gz}")"
step_7="$(echo_completion_file "${outpath}" 7 "${infile%.gz}")"


#  01: Copy files of interest to ${TMPDIR} ------------------------------------
if [[ ! -f "${step_1}" ]]; then
    echo -e "Started step 1/8: Copying ${base} into ${TMPDIR}."
    cp "${infile}" "${TMPDIR}" && \
    touch "${step_1}" && \
    echo -e "Completed step 1/8: Copying ${base} into ${TMPDIR}.\n"
else
    echo_completion_message 1
    :
fi


#  02: Identify and write out QNAMEs with more than one entry -----------------
if [[ ! -f "${step_2}" && -f "${step_1}" ]]; then
    echo -e "Started step 2/8: Tallying numbers of entries per QNAME in ${tmp}, retaining only those with more than one entry in an outlist."
    tally_qnames_gt_1_gzip "${tmp}" "${tmp_tally_gt_1}" && \
    touch "${step_2}" && \
    echo -e "Completed step 2/8: Tallying numbers of entries per QNAME in ${tmp}, retaining only those with more than one entry in an outlist.\n"
elif [[ -f "${step_2}" && -f "${step_1}" ]]; then
    echo_completion_message 2
    :
else
    echo_exit_message 2
    exit 1
fi


#  03: Retain only the QNAME column in the outlist ----------------------------
if [[ ! -f "${step_3}" && -f "${step_2}" ]]; then
    echo -e "Started step 3/8: Cutting away the tally column in ${tmp_tally_gt_1}."
    zcat "${tmp_tally_gt_1}" | cut -f2 | gzip > "${cut}" && \
    touch "${step_3}" && \
    echo -e "Completed step 3/8: Cutting away the tally column in ${tmp_tally_gt_1}.\n"
elif [[ -f "${step_3}" && -f "${step_2}" ]]; then
    echo_completion_message 3
    :
else
    echo_exit_message 3
    exit 1
fi


#  04: Using the duplicate QNAME outlist, filter the AS.txt.gz file -----------
if [[ ! -f "${step_4}" && -f "${step_3}" ]]; then
    echo -e "Started step 4/8: Removing duplicate QNAME lines from ${tmp}."
    filter_duplicate_qnames_gzip "${tmp}" "${cut}" "${corrected}" && \
    touch "${step_4}" && \
    echo -e "Completed step 4/8: Removing duplicate QNAME lines from ${tmp}.\n"
elif [[ -f "${step_4}" && -f "${step_3}" ]]; then
    echo_completion_message 4
    :
else
    echo_exit_message 4
    exit 1
fi


#  05: Count lines in files (infile, outfiles; optional) ----------------------
if [[ ! -f "${step_5}" && -f "${step_4}" ]]; then
    if [[ "${count}" == 1 ]]; then
        tmp_count="$(count_lines_gzip "${tmp}")"
        tmp_tally_gt_1_count="$(count_lines_gzip "${tmp_tally_gt_1}")"
        cut_count="$(count_lines_gzip "${cut}")"
        corrected_count="$(count_lines_gzip "${corrected}")"
        difference="$(( tmp_count - corrected_count ))"
        divide="$(echo "${difference} / 2" | bc)"

        echo -e "Started step 5/8: Counting entries in files, writing out lists."
        echo "Lines in $(basename "${tmp}"): ${tmp_count}" && \
        echo "Lines in $(basename "${tmp_tally_gt_1}"): ${tmp_tally_gt_1_count}" && \
        echo "Lines in $(basename "${cut}"): ${cut_count}" && \
        echo "Lines in $(basename "${corrected}"): ${corrected_count}" && \
        echo "Difference between $(basename "${tmp}") and $(basename "${corrected}"): ${difference}" && \
        echo "Difference divided by two: ${divide}" && \
        echo "" && \
        touch "${step_5}" && \
        echo -e "Completed step 5/8: Counting entries in files, writing out lists.\n"
    fi
elif [[ -f "${step_5}" && -f "${step_4}" ]]; then
    if [[ "${count}" == 1 ]]; then
        tmp_count="$(count_lines_gzip "${tmp}")"
        tmp_tally_gt_1_count="$(count_lines_gzip "${tmp_tally_gt_1}")"
        cut_count="$(count_lines_gzip "${cut}")"
        corrected_count="$(count_lines_gzip "${corrected}")"
        difference="$(( tmp_count - corrected_count ))"
        divide="$(echo "${difference} / 2" | bc)"

        echo_completion_message 5
        echo "Lines in $(basename "${tmp}"): ${tmp_count}" && \
        echo "Lines in $(basename "${tmp_tally_gt_1}"): ${tmp_tally_gt_1_count}" && \
        echo "Lines in $(basename "${cut}"): ${cut_count}" && \
        echo "Lines in $(basename "${corrected}"): ${corrected_count}" && \
        echo "Difference between $(basename "${tmp}") and $(basename "${corrected}"): ${difference}" && \
        echo "Difference divided by two: ${divide}"
        echo ""
    fi
else
    echo_exit_message 5
    exit 1
fi


#  06: Tally entries in files (infile, outfiles; optional) --------------------
if [[ ! -f "${step_6}" && -f "${step_4}" ]]; then
    if [[ "${tally}" == 1 ]]; then
        echo -e "Started step 6/8: Tallying entries in files, writing out lists."
        tally_qnames_gzip "${tmp}" "${tmp_tally}" && \
        tally_qnames_gzip "${corrected}" "${corrected_tally}" && \
        touch "${step_6}" && \
        echo -e "Completed step 6/8: Tallying entries in files, writing out lists.\n"
    fi
elif [[ -f "${step_6}" && -f "${step_4}" ]]; then
    echo_completion_message 6
    :
else
    echo_exit_message 6
    exit 1
fi


#  07: Remove intermediate files (optional) -----------------------------------
#TODO


#  08: Move outfiles from "${TMPDIR}" to "${outpath}" -------------------------
if [[ -f "${step_4}" && -f "${corrected}" ]]; then
    echo -e "Started step 8/8: Moving outfiles from ${TMPDIR} to ${outpath}."
    mv -f "${TMPDIR}/"*{.txt,.txt.gz} "${outpath}" && \
    touch "${step_7}" && \
    echo -e "Completed step 8/8: Moving outfiles from ${TMPDIR} to ${outpath}.\n"
fi


#  Return run time ------------------------------------------------------------
time_end="$(date +%s)"
calculate_run_time "${time_start}" "${time_end}" "Completed: ${0}"
echo -e ""

exit 0