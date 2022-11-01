#!/bin/bash

SOURCE_FILE_NAME="Main.c";
COMPILED_FILE_NAME="a.out";
TEMPORARY_FILE_1="/tmp/progtest-tmp1.txt";
TEMPORARY_FILE_2="/tmp/progtest-tmp2.txt";
HASH_FILE_NAME=".hash.txt";
INPUT_FILE_SUFFIX="_in.txt";
OUTPUT_FILE_SUFFIX="_out.txt";

RED_BOLD_COLOR="\033[1;31m";
GREEN_BOLD_COLOR="\033[1;32m";
YELLOW_BOLD_COLOR="\033[1;33m";
NO_COLOR="\033[0;0m";

TIMEFORMAT='%3lR';

DETAILED_TEST_OUTPUT=false;
LATEST_FOLDER_ONLY=false;
CONTINUE_AFTER_ERROR=false;
COMPILATION_SKIPPING_ALLOWED=false;
IGNORE_SUCCESS_MESSAGES=false;
RUN_WITHOUT_TESTS=false;

SUCCESS_MESSAGE () {
    if [ "$IGNORE_SUCCESS_MESSAGES" = true ]; then
        echo -en "${GREEN_BOLD_COLOR}${1}${NO_COLOR}";
        echo -en "\r\033[K";
    else
        echo -e "${GREEN_BOLD_COLOR}${1}${NO_COLOR}";
    fi;
}

ERROR_MESSAGE () {
    echo -e "${RED_BOLD_COLOR}${1}${NO_COLOR}";
}

WARNING_MESSAGE () {
    echo -e "${YELLOW_BOLD_COLOR}${1}${NO_COLOR}";
}

SEPARATOR () {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -;
} ;

GET_PREFIX_COLOR () {
    echo -e "\033[0;3$((1 + $1 % 6))m";
} ;

TEST_RESULTS () {
    if [ "$RUN_WITHOUT_TESTS" = false ]; then
        OUTPUT_DIFFERENCE=$(diff -y "$3" "$TEMPORARY_FILE_1" 2> /dev/null);
        DIFF_STATUS="$?";
    fi;
    case "$1" in 
        0)
            if [ "$RUN_WITHOUT_TESTS" = true ]; then
                SUCCESS_MESSAGE "NO ERRORS FOUND, $TIME_SPENT";
                return;
            fi;
            if [ "$DIFF_STATUS" -eq 0 ]; then
                if [ "$DETAILED_TEST_OUTPUT" = true ]; then
                    SUCCESS_MESSAGE "OK, $TIME_SPENT";
                fi;
                return 0;
            else
                if [ "$DETAILED_TEST_OUTPUT" = true ]; then
                    WARNING_MESSAGE "FAILED, $TIME_SPENT";
                fi;
            fi;
            ;;
        130)
            if [ "$DETAILED_TEST_OUTPUT" = true ] || [ "$RUN_WITHOUT_TESTS" = true ]; then
                WARNING_MESSAGE "TERMINATED, $TIME_SPENT";
            fi;
            ;;
        134)
            if [ "$DETAILED_TEST_OUTPUT" = true ] || [ "$RUN_WITHOUT_TESTS" = true ]; then
                ERROR_MESSAGE "FAILED ASSERTION, $TIME_SPENT";
            fi;
            ;;
        139)
            if [ "$DETAILED_TEST_OUTPUT" = true ] || [ "$RUN_WITHOUT_TESTS" = true ]; then
                ERROR_MESSAGE "SEGMENTATION FAULT, $TIME_SPENT";
            fi;
            ;;
        *)
            if [ "$DETAILED_TEST_OUTPUT" = true ] || [ "$RUN_WITHOUT_TESTS" = true ]; then
                ERROR_MESSAGE "RETURN VALUE $RETURN_VALUE, $TIME_SPENT";
            fi;
            ;;
    esac
    if [ "$RUN_WITHOUT_TESTS" = true ]; then
        return;
    fi;
    if [ "$DETAILED_TEST_OUTPUT" = true ]; then
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
        if [ "$DETAILED_TEST_OUTPUT" = true ]; then
            echo -en "$1 Testing $2 ... ";
        fi;
        OUTPUT_FILE=${2%"$3"}$4;
        \time -f "%es" --quiet -o "$TEMPORARY_FILE_2" ./$COMPILED_FILE_NAME < "$2" > "$TEMPORARY_FILE_1" 2>&1;
        RETURN_VALUE="$?";
        TIME_SPENT=$(cat "$TEMPORARY_FILE_2");
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
        if [ "$DETAILED_TEST_OUTPUT" = false ]; then
            echo -en "$1 Testing $2 inputs ... ";
        fi;
        SUCCESSFUL_TEST_COUNT=0;
        MAXIMUM_TEST_COUNT=$(echo "$2/"*"$3" | wc -w);
        for INPUT_FILE in "$2/"*"$3"; do
            if ! SINGLE_TEST "$1" "$INPUT_FILE" "$3" "$4"; then
                if [ "$CONTINUE_AFTER_ERROR" = false ]; then
                    if [ "$DETAILED_TEST_OUTPUT" = true ]; then
                        exit 1;
                    else
                        break;
                    fi;
                fi;
            fi;
        done;
        if [ "$DETAILED_TEST_OUTPUT" = false ]; then
            case $SUCCESSFUL_TEST_COUNT in
                "$MAXIMUM_TEST_COUNT")
                    SUCCESS_MESSAGE "$SUCCESSFUL_TEST_COUNT/$MAXIMUM_TEST_COUNT";
                    ;;
                0)
                    ERROR_MESSAGE "$SUCCESSFUL_TEST_COUNT/$MAXIMUM_TEST_COUNT";
                    if [ "$CONTINUE_AFTER_ERROR" = false ]; then
                        exit 1;
                    fi;
                    ;;
                *)
                    WARNING_MESSAGE "$SUCCESSFUL_TEST_COUNT/$MAXIMUM_TEST_COUNT";
                    if [ "$CONTINUE_AFTER_ERROR" = false ]; then
                        exit 1;
                    fi;
                    ;;
            esac
        fi;
    fi;
} ;

COMPILE () {
    echo -en "$1 Compiling source code ... ";
    if [ ! -f $SOURCE_FILE_NAME ]; then
        ERROR_MESSAGE "NOT FOUND";
        if [ "$CONTINUE_AFTER_ERROR" = false ]; then
            exit 0;
        else
            return;
        fi;
    fi;
    if [ -f $COMPILED_FILE_NAME ]; then
        md5sum "$SOURCE_FILE_NAME" > "$TEMPORARY_FILE_1";
        md5sum "$COMPILED_FILE_NAME" >> "$TEMPORARY_FILE_1";
    fi;
    diff "$HASH_FILE_NAME" "$TEMPORARY_FILE_1" > /dev/null 2>&1;
    if [ ! $? -eq 0 ] || [ ! -f "$COMPILED_FILE_NAME" ] || [ "$COMPILATION_SKIPPING_ALLOWED" = false ]; then
        COMPILATION_MESSAGES=$(g++ -Wall -pedantic "$SOURCE_FILE_NAME" -o "$COMPILED_FILE_NAME" -fdiagnostics-color=always 2>&1);
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
            rm "$HASH_FILE_NAME" 2> /dev/null;
            if [ "$CONTINUE_AFTER_ERROR" = false ]; then
                exit;
            else
                return 1;
            fi;
        fi;
        md5sum "$SOURCE_FILE_NAME" > "$HASH_FILE_NAME";
        md5sum "$COMPILED_FILE_NAME" >> "$HASH_FILE_NAME";
    else
        SUCCESS_MESSAGE "SKIPPED";
    fi;
    return 0;
} ;

RUN_PROGRAM () {
    cd "$2" || exit 1;
    PREFIX="$(GET_PREFIX_COLOR "$1")$2${NO_COLOR}:";
    if COMPILE "$PREFIX"; then
        if [ "$RUN_WITHOUT_TESTS" = false ]; then
            for FOLDER in */; do
                if [ -d "$FOLDER" ]; then
                    TEST_CASE "$PREFIX" "${FOLDER::-1}" "$INPUT_FILE_SUFFIX" "$OUTPUT_FILE_SUFFIX";
                fi;
            done;
        else
            SEPARATOR;
            \time -f "%es" --quiet -o "$TEMPORARY_FILE_1" ./$COMPILED_FILE_NAME;
            RETURN_VALUE="$?";
            TIME_SPENT=$(cat "$TEMPORARY_FILE_1");
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

LIST_ALL_OPTIONS () {
    COUNT=1;
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    echo -e "$COLOR-h$NO_COLOR, $COLOR--help$NO_COLOR: Show help and exit";
    COUNT=$((COUNT+1));
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    echo -e "$COLOR-l$NO_COLOR, $COLOR--latest$NO_COLOR: Perform tests only on latest folder";
    COUNT=$((COUNT+1));
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    echo -e "$COLOR-d$NO_COLOR, $COLOR--detailed$NO_COLOR: Show detailed test output";
    COUNT=$((COUNT+1));
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    echo -e "$COLOR-c$NO_COLOR, $COLOR--continue$NO_COLOR: Continue after an error occurs";
    COUNT=$((COUNT+1));
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    echo -e "$COLOR-s$NO_COLOR, $COLOR--skip$NO_COLOR: Skip compilation when possible";
    COUNT=$((COUNT+1));
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    echo -e "$COLOR-q$NO_COLOR, $COLOR--quiet$NO_COLOR: Shows only error and warning messages";
    COUNT=$((COUNT+1));
    COLOR=$(GET_PREFIX_COLOR "$COUNT");
    echo -e "$COLOR-r$NO_COLOR, $COLOR--run$NO_COLOR: Run a program directly (without tests). Should be combined with \"-l\".";
} ;

PROCESS_OPTION () {
    case $1 in
        -h|--help)
            LIST_ALL_OPTIONS;
            exit;
            ;;
        -l|--latest)
            LATEST_FOLDER_ONLY=true;
            ;;
        -d|--detailed)
            DETAILED_TEST_OUTPUT=true;
            ;;
        -c|--continue)
            CONTINUE_AFTER_ERROR=true;
            ;;
        -s|--skip)
            COMPILATION_SKIPPING_ALLOWED=true;
            ;;
        -q|--quiet)
            IGNORE_SUCCESS_MESSAGES=true;
            ;;
        -r|--run)
            RUN_WITHOUT_TESTS=true;
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
            break;
    esac
    shift;
done

if $LATEST_FOLDER_ONLY; then
    TEST_LATEST_FOLDER;
else
    TEST_ALL_FOLDERS;
fi;