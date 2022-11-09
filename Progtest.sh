#!/bin/bash

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

# Colors
white_bold_color="\033[1;37m";
red_bold_color="\033[1;31m";
green_bold_color="\033[1;32m";
yellow_bold_color="\033[1;33m";
no_color="\033[0;0m";

# Options
detailed_test_output=false;
latest_folder_only=false;
continue_after_error=false;
compilation_skipping_allowed=false;
ignore_success_messages=false;
run_without_tests=false;
selected_folder_name=;

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

separating_line () {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -;
} ;

get_prefix_color () {
    echo -e "\033[0;3$((1 + $1 % 6))m";
} ;

test_results () {
    if [ "$run_without_tests" = false ]; then
        output_difference=$(diff "$3" "$temporary_file_1" 2> /dev/null);
        difference_status="$?";
    fi;
    case "$1" in 
        0)
            if [ "$run_without_tests" = true ]; then
                success_message "NO ERRORS FOUND, $time_spent";
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
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                warning_message "TERMINATED BY CTRL+C, $time_spent";
            fi;
            ;;
        134)
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                error_message "ABORTED (FAILED ASSERT?), $time_spent";
            fi;
            ;;
        136)
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                error_message "FLOATING POINT EXCEPTION, $time_spent";
            fi;
            ;;
        139)
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                error_message "SEGMENTATION FAULT, $time_spent";
            fi;
            ;;
        *)
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                error_message "PROGRAM RETURNED $return_value, $time_spent";
            fi;
            ;;
    esac
    if [ "$run_without_tests" = true ]; then
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
        compilation_messages=$(g++ -Wall -pedantic "$source_file_name" -o "$compiled_file_name" -fdiagnostics-color=always 2>&1);
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
    extraction_file_count=$(cat "$temporary_file_1" | wc -l);
    extraction_warning_count=$(cat "$temporary_file_2" | wc -l);
    if [ ! $extraction_warning_count -eq 0 ]; then
        extraction_warning_count=$(($extraction_warning_count - 1));
    fi;
    successful_extraction_count=$(($extraction_file_count - $extraction_warning_count));
    if (( successful_extraction_count > 0 )); then
        success_message "$successful_extraction_count FILES EXTRACTED";
    else
        if [ $extraction_file_count -eq 0 ]; then
            error_message "NO FILES HAVE MATCHING NAMES";
            if [ "$continue_after_error" = false ]; then
                exit 1;
            fi;
        else
            success_message "NO NEW FILES FOUND";
        fi;
    fi;
} ;

run_program () {
    if [ ! -d "$2" ]; then
        error_message "Cannot find folder '$2'.";
        exit 1;
    fi;
    cd "$2" 2>/dev/null || exit 1;
    prefix_text="$(get_prefix_color "$1")$2${no_color}:";
    extract_sample_files "$prefix_text";
    if compile_source_code "$prefix_text"; then
        if [ "$run_without_tests" = false ]; then
            for folder_name in */; do
                if [ -d "$folder_name" ]; then
                    test_case "$prefix_text" "${folder_name::-1}" "$input_file_suffix" "$output_file_suffix";
                fi;
            done;
        else
            separating_line;
            /usr/bin/time -f "%es" --quiet -o "$temporary_file_1" ./$compiled_file_name;
            return_value="$?";
            time_spent=$(cat "$temporary_file_1");
            separating_line;
            echo -en "$prefix_text Getting result ... ";
            test_results "$return_value";
        fi;
    fi;
    cd ..;
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

test_latest_folder () {
    folder_count=$(ls -d * 2>/dev/null | wc -l);
    if [ "$folder_count" -eq 0 ]; then
        error_message "No folder found!";
        exit 1;
    fi;
    latest_folder=$(ls -td */ | head -1);
    run_program 1 "${latest_folder::-1}";
} ;

show_help () {
    show_heading "Options:";
    color_count=1;
    color_text=$(get_prefix_color "$color_count");
    echo -e "$color_text-h$no_color, $color_text--help$no_color: Show help and exit";
    color_count=$((color_count+1));
    color_text=$(get_prefix_color "$color_count");
    echo -e "$color_text-l$no_color, $color_text--latest$no_color: Perform tests only on latest folder";
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
    echo -e "$color_text-r$no_color, $color_text--run$no_color: Run a program directly (without tests).";
    echo "";
    show_heading "Arguments:";
    echo "This program takes one optional argument: address to a single folder with a program you want to test. If not provided (and option --latest is not being used), the program will run on all folders inside working directory.";
    echo "";
    show_heading "Usage:";
    echo "This program runs best with the following file structure (names of folders do not matter, however source code should be saved in Main.c and test files should have the *_in.txt and *_out.txt suffix).";
    color_count=$((color_count+1));
    color_text=$(get_prefix_color "$color_count");
    printf "\n%shw00/%s\n" "$color_text" "$no_color"
    printf "    %s\n" "sample/";
    printf "        %s\n" "0000_in.txt" "0000_out.txt" "...";
    printf "    %s\n" "custom/";
    printf "        %s\n" "...";
    printf "    %s\n" "Main.c";
    color_count=$((color_count+1));
    color_text=$(get_prefix_color "$color_count");
    printf "\n%shw01a/%s\n" "$color_text" "$no_color"
    printf "    %s\n" "sample/";
    printf "        %s\n" "...";
    printf "    %s\n" "Main.c";
    echo "";
    echo "With no options or arguments provided, the script attempts to compile, run and test all programs inside the working directory.";
} ;

process_option () {
    case $1 in
        -h|--help)
            show_help;
            exit;
            ;;
        -l|--latest)
            latest_folder_only=true;
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
        -r|--run)
            run_without_tests=true;
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

if [ -n "$selected_folder_name" ]; then
    run_program 1 "$1";
else
    if $latest_folder_only; then
        test_latest_folder;
    else
        test_all_folders;
    fi;
fi;