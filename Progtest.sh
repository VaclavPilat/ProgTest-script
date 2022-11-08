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

SUCCESS_MESSAGE () {
    if [ "$ignore_success_messages" = true ]; then
        echo -en "$green_bold_color$1$no_color";
        echo -en "\r\033[K";
    else
        echo -e "$green_bold_color$1$no_color";
    fi;
}

HEADING () {
    echo -e "$white_bold_color$1$no_color";
} ;

ERROR_MESSAGE () {
    echo -e "$red_bold_color$1$no_color";
} ;

WARNING_MESSAGE () {
    echo -e "$yellow_bold_color$1$no_color";
} ;

SEPARATOR () {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -;
} ;

GET_PREFIX_COLOR () {
    echo -e "\033[0;3$((1 + $1 % 6))m";
} ;

TEST_RESULTS () {
    if [ "$run_without_tests" = false ]; then
        OUTPUT_DIFFERENCE=$(diff "$3" "$temporary_file_1" 2> /dev/null);
        DIFF_STATUS="$?";
    fi;
    case "$1" in 
        0)
            if [ "$run_without_tests" = true ]; then
                SUCCESS_MESSAGE "NO ERRORS FOUND, $TIME_SPENT";
                return;
            fi;
            if [ "$DIFF_STATUS" -eq 0 ]; then
                if [ "$detailed_test_output" = true ]; then
                    SUCCESS_MESSAGE "OK, $TIME_SPENT";
                fi;
                return 0;
            else
                if [ "$detailed_test_output" = true ]; then
                    WARNING_MESSAGE "FAILED, $TIME_SPENT";
                fi;
            fi;
            ;;
        130)
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                WARNING_MESSAGE "TERMINATED BY CTRL+C, $TIME_SPENT";
            fi;
            ;;
        134)
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                ERROR_MESSAGE "ABORTED (FAILED ASSERT?), $TIME_SPENT";
            fi;
            ;;
        136)
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                ERROR_MESSAGE "FLOATING POINT EXCEPTION, $TIME_SPENT";
            fi;
            ;;
        139)
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                ERROR_MESSAGE "SEGMENTATION FAULT, $TIME_SPENT";
            fi;
            ;;
        *)
            if [ "$detailed_test_output" = true ] || [ "$run_without_tests" = true ]; then
                ERROR_MESSAGE "PROGRAM RETURNED $RETURN_VALUE, $TIME_SPENT";
            fi;
            ;;
    esac
    if [ "$run_without_tests" = true ]; then
        return;
    fi;
    if [ "$detailed_test_output" = true ]; then
        SEPARATOR;
        cat "$2";
        SEPARATOR;
        echo "$OUTPUT_DIFFERENCE";
        SEPARATOR;
    fi;
    return 1;
} ;

SINGLE_TEST () {
    if [ -f "$2" ]; then
        if [ "$detailed_test_output" = true ]; then
            echo -en "$1 Testing $2 ... ";
        fi;
        OUTPUT_FILE=${2%"$3"}$4;
        \time -f "%es" --quiet -o "$temporary_file_2" ./$compiled_file_name < "$2" > "$temporary_file_1" 2>&1;
        RETURN_VALUE="$?";
        TIME_SPENT=$(cat "$temporary_file_2");
        if TEST_RESULTS "$RETURN_VALUE" "$2" "$OUTPUT_FILE"; then 
            SUCCESSFUL_TEST_COUNT=$((SUCCESSFUL_TEST_COUNT+1));
            return 0;
        else
            return 1;
        fi;
    fi;
} ;

TEST_CASE () {
    if [ -d "$2" ]; then
        if [ "$detailed_test_output" = false ]; then
            echo -en "$1 Testing $2 inputs ... ";
        fi;
        SUCCESSFUL_TEST_COUNT=0;
        MAXIMUM_TEST_COUNT=$(echo "$2/"*"$3" | wc -w);
        for INPUT_FILE in "$2/"*"$3"; do
            if ! SINGLE_TEST "$1" "$INPUT_FILE" "$3" "$4"; then
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
                    SUCCESS_MESSAGE "$SUCCESSFUL_TEST_COUNT/$MAXIMUM_TEST_COUNT";
                    ;;
                0)
                    ERROR_MESSAGE "$SUCCESSFUL_TEST_COUNT/$MAXIMUM_TEST_COUNT";
                    if [ "$continue_after_error" = false ]; then
                        exit 1;
                    fi;
                    ;;
                *)
                    WARNING_MESSAGE "$SUCCESSFUL_TEST_COUNT/$MAXIMUM_TEST_COUNT";
                    if [ "$continue_after_error" = false ]; then
                        exit 1;
                    fi;
                    ;;
            esac
        fi;
    fi;
} ;

COMPILE () {
    echo -en "$1 Compiling source code ... ";
    if [ ! -f $source_file_name ]; then
        ERROR_MESSAGE "NOT FOUND";
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
                WARNING_MESSAGE "WARNING";
            else
                SUCCESS_MESSAGE "OK";
            fi;
        else
            ERROR_MESSAGE "FAILED";
        fi;
        if [ ! $? -eq 0 ] || [[ $COMPILATION_MESSAGES ]]; then
            SEPARATOR;
            echo "$COMPILATION_MESSAGES";
            SEPARATOR;
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
        SUCCESS_MESSAGE "SKIPPED";
    fi;
    return 0;
} ;

RUN_PROGRAM () {
    if [ ! -d "$2" ]; then
        ERROR_MESSAGE "Cannot find folder '$2'.";
        exit 1;
    fi;
    cd "$2" 2>/dev/null || exit 1;
    PREFIX="$(GET_PREFIX_COLOR "$1")$2${no_color}:";
    if COMPILE "$PREFIX"; then
        if [ "$run_without_tests" = false ]; then
            for FOLDER in */; do
                if [ -d "$FOLDER" ]; then
                    TEST_CASE "$PREFIX" "${FOLDER::-1}" "$input_file_suffix" "$output_file_suffix";
                fi;
            done;
        else
            SEPARATOR;
            \time -f "%es" --quiet -o "$temporary_file_1" ./$compiled_file_name;
            RETURN_VALUE="$?";
            TIME_SPENT=$(cat "$temporary_file_1");
            SEPARATOR;
            echo -en "$PREFIX Getting result ... ";
            TEST_RESULTS "$RETURN_VALUE";
        fi;
    fi;
    cd ..;
} ;

TEST_ALL_FOLDERS () {
    COUNT=1
    for FOLDER in */; do
        if [ -d "$FOLDER" ]; then
            RUN_PROGRAM $COUNT "${FOLDER::-1}";
            COUNT=$((COUNT+1));
        fi;
    done;
} ;

TEST_LATEST_FOLDER () {
    FOLDER_COUNT=$(ls -d * 2>/dev/null | wc -l);
    if [ "$FOLDER_COUNT" -eq 0 ]; then
        ERROR_MESSAGE "No folder found!";
        exit 1;
    fi;
    LATEST=$(ls -td */ | head -1);
    RUN_PROGRAM 1 "${LATEST::-1}";
} ;

SHOW_HELP () {
    HEADING "Options:";
    COUNT=1;
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    echo -e "$COLOR-h$no_color, $COLOR--help$no_color: Show help and exit";
    COUNT=$((COUNT+1));
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    echo -e "$COLOR-l$no_color, $COLOR--latest$no_color: Perform tests only on latest folder";
    COUNT=$((COUNT+1));
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    echo -e "$COLOR-d$no_color, $COLOR--detailed$no_color: Show detailed test output";
    COUNT=$((COUNT+1));
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    echo -e "$COLOR-c$no_color, $COLOR--continue$no_color: Continue after an error occurs";
    COUNT=$((COUNT+1));
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    echo -e "$COLOR-s$no_color, $COLOR--skip$no_color: Skip compilation when possible";
    COUNT=$((COUNT+1));
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    echo -e "$COLOR-q$no_color, $COLOR--quiet$no_color: Shows only error and warning messages";
    COUNT=$((COUNT+1));
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    echo -e "$COLOR-r$no_color, $COLOR--run$no_color: Run a program directly (without tests).";
    echo "";
    HEADING "Arguments:";
    echo "This program takes one optional argument: address to a single folder with a program you want to test. If not provided (and option --latest is not being used), the program will run on all folders inside working directory.";
    echo "";
    HEADING "Usage:";
    echo "This program runs best with the following file structure (names of folders do not matter, however source code should be saved in Main.c and test files should have the *_in.txt and *_out.txt suffix).";
    COUNT=$((COUNT+1));
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    printf "\n${COLOR}hw00/${no_color}\n"
    printf "    %s\n" "sample/";
    printf "        %s\n" "0000_in.txt" "0000_out.txt" "...";
    printf "    %s\n" "custom/";
    printf "        %s\n" "...";
    printf "    %s\n" "Main.c";
    COUNT=$((COUNT+1));
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    printf "${COLOR}hw01a/${no_color}\n"
    printf "    %s\n" "sample/";
    printf "        %s\n" "...";
    printf "    %s\n" "Main.c";
    echo "";
    echo "With no options or arguments provided, the script attempts to compile, run and test all programs inside the working directory.";
} ;

PROCESS_OPTION () {
    case $1 in
        -h|--help)
            SHOW_HELP;
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
            ERROR_MESSAGE "Unknown option: '$1', use '--help' to get list of usable options";
            exit 1;
            ;;
    esac
} ;

while :; do
    case $1 in
        -?|--*)
            PROCESS_OPTION "$1";
            ;;
        -?*)
            OPTIONS="${1:1}";
            while read -n 1 OPTION; do
                if [[ $OPTION ]]; then
                    PROCESS_OPTION "-$OPTION";
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
    RUN_PROGRAM 1 "$1";
else
    if $latest_folder_only; then
        TEST_LATEST_FOLDER;
    else
        TEST_ALL_FOLDERS;
    fi;
fi;