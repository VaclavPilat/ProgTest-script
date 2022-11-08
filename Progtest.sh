#!/bin/bash

# File names
source_file_name="Main.c";
compiled_file_name="a.out";
temporary_file_1="/tmp/progtest-tmp1.txt";
temporary_file_2="/tmp/progtest-tmp2.txt";
hash_file_name=".hash.txt";
input_file_suffix="_in.txt";
output_file_suffix="_out.txt";

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
        echo -en "$green_bold_color$1$no_color";
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
        OUTPUT_DIFFERENCE=$(diff "$3" "$temporary_file_1" 2> /dev/null);
        DIFF_STATUS="$?";
    fi;
    case "$1" in 
        0)
            if [ "$run_without_tests" = true ]; then
                success_message "NO ERRORS FOUND, $TIME_SPENT";
                return;
            fi;
            if [ "$DIFF_STATUS" -eq 0 ]; then
                if [ "$detailed_test_output" = true ]; then
                    success_message "OK, $TIME_SPENT";
                fi;
                return 0;
            else
                if [ "$detailed_test_output" = true ]; then
                    warning_message "FAILED, $TIME_SPENT";
                fi;
            fi;
            ;;
        130)
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                warning_message "TERMINATED BY CTRL+C, $TIME_SPENT";
            fi;
            ;;
        134)
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                error_message "ABORTED (FAILED ASSERT?), $TIME_SPENT";
            fi;
            ;;
        136)
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                error_message "FLOATING POINT EXCEPTION, $TIME_SPENT";
            fi;
            ;;
        139)
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                error_message "SEGMENTATION FAULT, $TIME_SPENT";
            fi;
            ;;
        *)
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                error_message "PROGRAM RETURNED $RETURN_VALUE, $TIME_SPENT";
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
        echo "$OUTPUT_DIFFERENCE";
        separating_line;
    fi;
    return 1;
} ;

single_test () {
    if [ -f "$2" ]; then
        if [ "$detailed_test_output" = true ]; then
            echo -en "$1 Testing $2 ... ";
        fi;
        OUTPUT_FILE=${2%"$3"}$4;
        \time -f "%es" --quiet -o "$temporary_file_2" ./$compiled_file_name < "$2" > "$temporary_file_1" 2>&1;
        RETURN_VALUE="$?";
        TIME_SPENT=$(cat "$temporary_file_2");
        if test_results "$RETURN_VALUE" "$2" "$OUTPUT_FILE"; then 
            SUCCESSFUL_TEST_COUNT=$((SUCCESSFUL_TEST_COUNT+1));
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
        SUCCESSFUL_TEST_COUNT=0;
        MAXIMUM_TEST_COUNT=$(echo "$2/"*"$3" | wc -w);
        for INPUT_FILE in "$2/"*"$3"; do
            if ! single_test "$1" "$INPUT_FILE" "$3" "$4"; then
                if [ "$continue_after_error" = false ]; then
                    if [ "$detailed_test_output" = true ]; then
                        exit 1;
                    else
                        break;
                    fi;
                fi;
            fi;
        done;
        if [ "$detailed_test_output" = false ]; then
            case $SUCCESSFUL_TEST_COUNT in
                "$MAXIMUM_TEST_COUNT")
                    success_message "$SUCCESSFUL_TEST_COUNT/$MAXIMUM_TEST_COUNT";
                    ;;
                0)
                    error_message "$SUCCESSFUL_TEST_COUNT/$MAXIMUM_TEST_COUNT";
                    if [ "$continue_after_error" = false ]; then
                        exit 1;
                    fi;
                    ;;
                *)
                    warning_message "$SUCCESSFUL_TEST_COUNT/$MAXIMUM_TEST_COUNT";
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
        COMPILATION_MESSAGES=$(g++ -Wall -pedantic "$source_file_name" -o "$compiled_file_name" -fdiagnostics-color=always 2>&1);
        if [ $? -eq 0 ]; then
            if [[ $COMPILATION_MESSAGES ]]; then
                warning_message "WARNING";
            else
                success_message "OK";
            fi;
        else
            error_message "FAILED";
        fi;
        if [ ! $? -eq 0 ] || [[ $COMPILATION_MESSAGES ]]; then
            separating_line;
            echo "$COMPILATION_MESSAGES";
            separating_line;
            rm "$hash_file_name" 2> /dev/null;
            if [ "$continue_after_error" = false ]; then
                exit;
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

run_program () {
    if [ ! -d "$2" ]; then
        error_message "Cannot find folder '$2'.";
        exit 1;
    fi;
    cd "$2" 2>/dev/null || exit 1;
    PREFIX="$(get_prefix_color "$1")$2${no_color}:";
    if compile_source_code "$PREFIX"; then
        if [ "$run_without_tests" = false ]; then
            for FOLDER in */; do
                if [ -d "$FOLDER" ]; then
                    test_case "$PREFIX" "${FOLDER::-1}" "$input_file_suffix" "$output_file_suffix";
                fi;
            done;
        else
            separating_line;
            \time -f "%es" --quiet -o "$temporary_file_1" ./$compiled_file_name;
            RETURN_VALUE="$?";
            TIME_SPENT=$(cat "$temporary_file_1");
            separating_line;
            echo -en "$PREFIX Getting result ... ";
            test_results "$RETURN_VALUE";
        fi;
    fi;
    cd ..;
} ;

test_all_folders () {
    COUNT=1
    for FOLDER in */; do
        if [ -d "$FOLDER" ]; then
            run_program $COUNT "${FOLDER::-1}";
            COUNT=$((COUNT+1));
        fi;
    done;
} ;

test_latest_folder () {
    FOLDER_COUNT=$(ls -d * 2>/dev/null | wc -l);
    if [ "$FOLDER_COUNT" -eq 0 ]; then
        error_message "No folder found!";
        exit 1;
    fi;
    LATEST=$(ls -td */ | head -1);
    run_program 1 "${LATEST::-1}";
} ;

show_help () {
    show_heading "Options:";
    COUNT=1;
    COLOR=$(get_prefix_color "$COUNT");
    echo -e "$COLOR-h$no_color, $COLOR--help$no_color: Show help and exit";
    COUNT=$((COUNT+1));
    COLOR=$(get_prefix_color "$COUNT");
    echo -e "$COLOR-l$no_color, $COLOR--latest$no_color: Perform tests only on latest folder";
    COUNT=$((COUNT+1));
    COLOR=$(get_prefix_color "$COUNT");
    echo -e "$COLOR-d$no_color, $COLOR--detailed$no_color: Show detailed test output";
    COUNT=$((COUNT+1));
    COLOR=$(get_prefix_color "$COUNT");
    echo -e "$COLOR-c$no_color, $COLOR--continue$no_color: Continue after an error occurs";
    COUNT=$((COUNT+1));
    COLOR=$(get_prefix_color "$COUNT");
    echo -e "$COLOR-s$no_color, $COLOR--skip$no_color: Skip compilation when possible";
    COUNT=$((COUNT+1));
    COLOR=$(get_prefix_color "$COUNT");
    echo -e "$COLOR-q$no_color, $COLOR--quiet$no_color: Shows only error and warning messages";
    COUNT=$((COUNT+1));
    COLOR=$(get_prefix_color "$COUNT");
    echo -e "$COLOR-r$no_color, $COLOR--run$no_color: Run a program directly (without tests).";
    echo "";
    show_heading "Arguments:";
    echo "This program takes one optional argument: address to a single folder with a program you want to test. If not provided (and option --latest is not being used), the program will run on all folders inside working directory.";
    echo "";
    show_heading "Usage:";
    echo "This program runs best with the following file structure (names of folders do not matter, however source code should be saved in Main.c and test files should have the *_in.txt and *_out.txt suffix).";
    COUNT=$((COUNT+1));
    COLOR=$(get_prefix_color "$COUNT");
    printf "\n${COLOR}hw00/${no_color}\n"
    printf "    %s\n" "sample/";
    printf "        %s\n" "0000_in.txt" "0000_out.txt" "...";
    printf "    %s\n" "custom/";
    printf "        %s\n" "...";
    printf "    %s\n" "Main.c";
    COUNT=$((COUNT+1));
    COLOR=$(get_prefix_color "$COUNT");
    printf "${COLOR}hw01a/${no_color}\n"
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
            OPTIONS="${1:1}";
            while read -n 1 OPTION; do
                if [[ $OPTION ]]; then
                    process_option "-$OPTION";
                fi;
            done <<< "$OPTIONS"
            ;;
        *)
            selected_folder_name="$1";
            break;
    esac
    shift;
done

if [ ! -z $selected_folder_name ]; then
    run_program 1 "$1";
else
    if $latest_folder_only; then
        test_latest_folder;
    else
        test_all_folders;
    fi;
fi;