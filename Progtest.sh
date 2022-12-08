#!/bin/bash

program_version=1.0;

# File names
source_file_name="Main.c";
compiled_file_name="a.out";
temporary_file_1="/tmp/progtest-tmp1.txt";
temporary_file_2="/tmp/progtest-tmp2.txt";
hash_file_name=".hash.txt";
input_file_suffix="_in.txt";
output_file_suffix="_out.txt";
sample_archive_name="sample.tgz";
sample_archive_folder="CZE";

compilation_command="g++ -Wall -pedantic -Wno-long-long -O2 $source_file_name -o $compiled_file_name -fdiagnostics-color=always";

# Default option values
detailed_test_output=false;
continue_after_error=false;
compilation_skipping_allowed=false;
ignore_success_messages=false;
selected_folder_name=;
remove_extracted_archive=false;
program_action_name=;
side_by_side_comparison=false;

# Colors
no_color="\033[0;0m";
red_bold_color="\033[1;31m";
green_bold_color="\033[1;32m";
yellow_bold_color="\033[1;33m";
white_bold_color="\033[1;37m";

show_heading () {
    echo -e "$white_bold_color$1$no_color";
} ;

success_message () {
    if [ "$ignore_success_messages" = true ]; then
        echo -en "\r\033[K";
    else
        echo -e "$green_bold_color$1$no_color";
    fi;
}

error_message () {
    echo -e "$red_bold_color$1$no_color";
} ;

warning_message () {
    echo -e "$yellow_bold_color$1$no_color";
} ;

info_message () {
    echo -e "$white_bold_color$1$no_color";
} ;

separating_line () {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -;
} ;

get_prefix_color () {
    echo -e "\033[0;3$((1 + $1 % 6))m";
} ;

test_results () {
    if [ -z "$program_action_name" ]; then
        if [ "$side_by_side_comparison" = true ]; then
            output_difference=$(diff -y <(nl -n'ln' "$3") <(nl -n'ln' "$temporary_file_1") 2> /dev/null);
            difference_status="$?";
        else
            output_difference=$(diff "$3" "$temporary_file_1" 2> /dev/null);
            difference_status="$?";
        fi;
    fi;
    case "$1" in 
        0)
            if [ -n "$program_action_name" ]; then
                if [ "$detailed_test_output" = true ]; then
                    success_message "NO ERRORS FOUND, $time_spent";
                    return;
                fi;
                success_message "NO ERRORS FOUND";
                return;
            fi;
            if [ "$difference_status" -eq 0 ]; then
                if [ "$detailed_test_output" = true ]; then
                    success_message "OK, $time_spent";
                fi;
                return 0;
            else
                if [ "$detailed_test_output" = true ]; then
                    warning_message "FAILED, $time_spent";
                fi;
            fi;
            ;;
        130)
            if [ "$detailed_test_output" = true ] || [ -n "$program_action_name" ]; then
                warning_message "TERMINATED BY CTRL+C, $time_spent";
            fi;
            ;;
        134)
            if [ "$detailed_test_output" = true ] || [ -n "$program_action_name" ]; then
                error_message "ABORTED (FAILED ASSERT?), $time_spent";
            fi;
            ;;
        136)
            if [ "$detailed_test_output" = true ] || [ -n "$program_action_name" ]; then
                error_message "FLOATING POINT EXCEPTION, $time_spent";
            fi;
            ;;
        139)
            if [ "$detailed_test_output" = true ] || [ -n "$program_action_name" ]; then
                error_message "SEGMENTATION FAULT, $time_spent";
            fi;
            ;;
        *)
            if [ "$detailed_test_output" = true ] || [ -n "$program_action_name" ]; then
                error_message "PROGRAM RETURNED $return_value, $time_spent";
            fi;
            ;;
    esac
    if [ -n "$program_action_name" ]; then
        return;
    fi;
    if [ "$detailed_test_output" = true ]; then
        separating_line;
        cat "$2";
        separating_line;
        echo "$output_difference";
        separating_line;
    fi;
    return 1;
} ;

single_test () {
    if [ -f "$2" ]; then
        if [ "$detailed_test_output" = true ]; then
            echo -en "$1 Testing $2 ... ";
        fi;
        output_file=${2%"$3"}$4;
        /usr/bin/time -f "%es" --quiet -o "$temporary_file_2" ./$compiled_file_name < "$2" > "$temporary_file_1" 2>&1;
        return_value="$?";
        time_spent=$(cat "$temporary_file_2");
        if test_results "$return_value" "$2" "$output_file"; then 
            return 0;
        else
            return 1;
        fi;
    fi;
} ;

test_case () {
    if [ -d "$2" ]; then
        if [ "$detailed_test_output" = false ]; then
            echo -en "$1 Testing $2 inputs ... ";
        fi;
        successful_test_count=0;
        maximum_test_count=$(echo "$2/"*"$3" | wc -w);
        for input_file in "$2/"*"$3"; do
            if ! single_test "$1" "$input_file" "$3" "$4"; then
                if [ "$continue_after_error" = false ]; then
                    if [ "$detailed_test_output" = true ]; then
                        exit 1;
                    else
                        break;
                    fi;
                fi;
            else
                successful_test_count=$((successful_test_count+1));
            fi;
        done;
        if [ "$detailed_test_output" = false ]; then
            case $successful_test_count in
                "$maximum_test_count")
                    success_message "$successful_test_count/$maximum_test_count";
                    ;;
                0)
                    error_message "$successful_test_count/$maximum_test_count";
                    if [ "$continue_after_error" = false ]; then
                        exit 1;
                    fi;
                    ;;
                *)
                    warning_message "$successful_test_count/$maximum_test_count";
                    if [ "$continue_after_error" = false ]; then
                        exit 1;
                    fi;
                    ;;
            esac
        fi;
    fi;
} ;

compile_source_code () {
    echo -en "$1 Compiling source code ... ";
    if [ -n "$additional_compilation_options" ]; then
        compilation_skipping_allowed=false;
    fi;
    if [ ! -f $source_file_name ]; then
        error_message "NOT FOUND";
        if [ "$continue_after_error" = false ]; then
            exit 0;
        else
            return;
        fi;
    fi;
    if [ -f $compiled_file_name ]; then
        md5sum "$source_file_name" > "$temporary_file_1";
        md5sum "$compiled_file_name" >> "$temporary_file_1";
    fi;
    diff "$hash_file_name" "$temporary_file_1" > /dev/null 2>&1;
    if [ ! $? -eq 0 ] || [ ! -f "$compiled_file_name" ] || [ "$compilation_skipping_allowed" = false ]; then
        compilation_messages=$($compilation_command 2>&1);
        if [ $? -eq 0 ]; then
            if [[ $compilation_messages ]]; then
                warning_message "WARNING";
            else
                success_message "OK";
            fi;
        else
            error_message "FAILED";
        fi;
        if [ ! $? -eq 0 ] || [[ $compilation_messages ]]; then
            separating_line;
            echo "$compilation_messages";
            separating_line;
            rm "$hash_file_name" 2> /dev/null;
            if [ "$continue_after_error" = false ]; then
                exit 1;
            else
                return 1;
            fi;
        fi;
        md5sum "$source_file_name" > "$hash_file_name";
        md5sum "$compiled_file_name" >> "$hash_file_name";
    else
        success_message "SKIPPED";
    fi;
    return 0;
} ;

extract_sample_files () {
    if [ ! -f $sample_archive_name ]; then
        return;
    fi;
    echo -en "$1 Extracting sample files ... ";
    tar --wildcards -xzvkf "$sample_archive_name" "*.c" "$sample_archive_folder/*$input_file_suffix" "$sample_archive_folder/*$output_file_suffix" > "$temporary_file_1" 2> "$temporary_file_2";
    extraction_file_count=$(wc -l < "$temporary_file_1");
    extraction_warning_count=$(wc -l < "$temporary_file_2");
    if [ ! "$extraction_warning_count" -eq 0 ]; then
        extraction_warning_count=$((extraction_warning_count - 1));
    fi;
    successful_extraction_count=$((extraction_file_count - extraction_warning_count));
    if (( successful_extraction_count > 0 )); then
        success_message "$successful_extraction_count FILES EXTRACTED";
    else
        if [ "$extraction_file_count" -eq 0 ]; then
            error_message "NO FILES HAVE MATCHING NAMES";
            if [ "$continue_after_error" = false ]; then
                exit 1;
            else
                return;
            fi;
        else
            success_message "NO NEW FILES FOUND";
        fi;
    fi;
    if [ "$remove_extracted_archive" = true ]; then
        echo -en "$1 Removing sample archive ... ";
        if rm "$sample_archive_name"; then
            success_message "ARCHIVE REMOVED";
        else
            error_message "REMOVAL FAILED";
            if [ "$continue_after_error" = false ]; then
                exit 1;
            fi;
        fi;
    fi;
} ;

start_program () {
    if [ ! -d "$2" ]; then
        error_message "Cannot find folder '$2'.";
        exit 1;
    fi;
    cd "$2" 2>/dev/null || exit 1;
    prefix_text="$(get_prefix_color "$1")$2${no_color}:";
    extract_sample_files "$prefix_text";
    if compile_source_code "$prefix_text"; then
        case $program_action_name in
            execute)
                if [ "$detailed_test_output" = true ]; then
                    separating_line;
                    /usr/bin/time -f "%es" --quiet -o "$temporary_file_1" ./$compiled_file_name;
                    return_value="$?";
                    time_spent=$(cat "$temporary_file_1");
                    separating_line;
                else
                    ./$compiled_file_name >/dev/null 2>&1;
                    return_value="$?";
                fi;
                echo -en "$prefix_text Getting result ... ";
                test_results "$return_value";
                ;;
            *)
                for folder_name in */; do
                    if [ -d "$folder_name" ]; then
                        test_case "$prefix_text" "${folder_name::-1}" "$input_file_suffix" "$output_file_suffix";
                    fi;
                done;
                ;;
        esac
    fi;
    cd ..;
} ;

run_program () {
    if [ "$program_action_name" = autoexecute ]; then
        folder_count=$(find "$2" -maxdepth 1 -type d | wc -l);
        if [ "$folder_count" -eq 1 ]; then
            program_action_name=execute;
        else
            program_action_name=;
        fi;
        start_program "$1" "$2";
        program_action_name=autoexecute;
    else
        start_program "$1" "$2";
    fi;
} ;

test_all_folders () {
    color_count=1
    for folder_name in */; do
        if [ -d "$folder_name" ]; then
            run_program $color_count "${folder_name::-1}";
            color_count=$((color_count+1));
        fi;
    done;
} ;

show_info () {
    script_basename=$(basename "$0");
    message_prefix="$white_bold_color$script_basename$no_color:";
    echo -en "$message_prefix To show program information, use option: ";
    info_message "--help";
    echo -en "$message_prefix Compilation command: ";
    info_message "$compilation_command";
} ;

show_version () {
    show_heading "ProgTest script v$program_version";
    echo "Written by Václav Pilát";
    echo "Report bugs by creating an issue on Github: https://github.com/VaclavPilat/ProgTest-script";
}

show_help () {
    color_count=1;
    show_heading "Usage:";
    echo "./Progtest.sh [options] [foldername]";
    echo "";
    show_heading "Examples of usage:";
    echo "./Progtest.sh -ac";
    echo "./Progtest.sh -adsrl hw07a";
    echo "";
    show_heading "Program information options:";
    color_text=$(get_prefix_color "$color_count");
    echo -e "$color_text-h$no_color, $color_text--help$no_color: Show help and exit";
    color_count=$((color_count+1));
    color_text=$(get_prefix_color "$color_count");
    echo -e "$color_text-v$no_color, $color_text--version$no_color: Show version and exit";
    echo "";
    show_heading "Modifier options (can be combined):";
    color_count=$((color_count+1));
    color_text=$(get_prefix_color "$color_count");
    echo -e "$color_text-d$no_color, $color_text--detailed$no_color: Show detailed test output";
    color_count=$((color_count+1));
    color_text=$(get_prefix_color "$color_count");
    echo -e "$color_text-c$no_color, $color_text--continue$no_color: Continue after an error occurs";
    color_count=$((color_count+1));
    color_text=$(get_prefix_color "$color_count");
    echo -e "$color_text-s$no_color, $color_text--skip$no_color: Skip compilation when possible";
    color_count=$((color_count+1));
    color_text=$(get_prefix_color "$color_count");
    echo -e "$color_text-q$no_color, $color_text--quiet$no_color: Shows only error and warning messages";
    color_count=$((color_count+1));
    color_text=$(get_prefix_color "$color_count");
    echo -e "$color_text-r$no_color, $color_text--remove$no_color: Remove sample archive after successful extraction";
    color_count=$((color_count+1));
    color_text=$(get_prefix_color "$color_count");
    echo -e "$color_text-l$no_color, $color_text--columns$no_color: Shows file comparison side by side";
    echo "";
    show_heading "Program action options (should not be combined):";
    color_count=$((color_count+1));
    color_text=$(get_prefix_color "$color_count");
    echo -e "$color_text-x$no_color, $color_text--execute$no_color: Execute a program directly (without tests)";
    color_count=$((color_count+1));
    color_text=$(get_prefix_color "$color_count");
    echo -e "$color_text-a$no_color, $color_text--autoexecute$no_color: Determine whether to perform tests or run directly";
    echo "";
    show_heading "Arguments:";
    echo "This program takes one optional argument: address to a single folder with a program you want to test. If not provided (and option --latest is not being used), the program will run on all folders inside working directory.";
    echo "";
    show_heading "Notes:";
    echo "The working directory should contain folders with programs. Each folder should have a source code file named \"Main.c\" and folders for test files. Here is an example:";
    echo "";
    echo "hw00/";
    echo "    CZE/";
    echo "        0000_in.txt";
    echo "        0000_out.txt";
    echo "    custom/";
    echo "        long_input_in.txt";
    echo "        long_input_out.txt";
    echo "    Main.c";
    echo "hw01a/";
    echo "    sample/";
    echo "        0000_in.txt";
    echo "        0000_out.txt";
    echo "    Main.c";
    echo "    sample.tgz";
    echo "";
    echo "With no options or arguments provided, the script attempts to compile, run and test all programs inside the working directory.";
} ;

process_option () {
    case $1 in
        -h|--help)
            show_help;
            exit;
            ;;
        -v|--version)
            show_version;
            exit;
            ;;
        -d|--detailed)
            detailed_test_output=true;
            ;;
        -c|--continue)
            continue_after_error=true;
            ;;
        -s|--skip)
            compilation_skipping_allowed=true;
            ;;
        -q|--quiet)
            ignore_success_messages=true;
            ;;
        -r|--remove)
            remove_extracted_archive=true;
            ;;
        -l|--columns)
            side_by_side_comparison=true;
            ;;
        -x|--execute)
            program_action_name=execute;
            ;;
        -a|--autoexecute)
            program_action_name=autoexecute;
            ;;
        *)
            error_message "Unknown option: '$1', use '--help' to get list of usable options";
            exit 1;
            ;;
    esac
} ;

while :; do
    case $1 in
        -?|--*)
            process_option "$1";
            ;;
        -?*)
            program_options="${1:1}";
            while read -rn 1 option_name; do
                if [[ $option_name ]]; then
                    process_option "-$option_name";
                fi;
            done <<< "$program_options"
            ;;
        *)
            selected_folder_name="$1";
            break;
    esac
    shift;
done

show_info;

if [ -n "$selected_folder_name" ]; then
    run_program 1 "$selected_folder_name";
else
    test_all_folders;
fi;