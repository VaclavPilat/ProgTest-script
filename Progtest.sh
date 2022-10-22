#!/bin/bash

SOURCE_FILE_NAME="Main.c";
COMPILED_FILE_NAME="a.out";
TEMPORARY_FILE_NAME="/tmp/tmp.txt";
HASH_FILE_NAME="hash.txt";
INPUT_FILE_SUFFIX="_in.txt";
OUTPUT_FILE_SUFFIX="_out.txt";

RED_BOLD_COLOR="\033[1;31m";
GREEN_BOLD_COLOR="\033[1;32m";
YELLOW_BOLD_COLOR="\033[1;33m";
NO_COLOR="\033[0;0m";

TIMEFORMAT='%3lR';

DETAILED_TEST_OUTPUT=false;
LATEST_FOLDER_ONLY=false;

SUCCESS_MESSAGE () {
    echo -e "${GREEN_BOLD_COLOR}${1}${NO_COLOR}";
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

TEST_CASE () {
    if [ -d "$2" ];
    then
        if [ "$DETAILED_TEST_OUTPUT" = false ];
        then
            echo -en "$1 Testing $2 inputs ... ";
        fi;
        SUCCESSFUL_TEST_COUNT=0;
        MAXIMUM_TEST_COUNT=$(echo "$2/"*"$3" | wc -w);
        for INPUT_FILE in "$2/"*"$3";
        do
            if [ -f "$INPUT_FILE" ];
            then
                if [ "$DETAILED_TEST_OUTPUT" = true ];
                then
                    echo -en "$1 Testing $INPUT_FILE ... ";
                fi;
                OUTPUT_FILE=${INPUT_FILE%"$3"}$4;
                TIME_SPENT=$({ time ./$COMPILED_FILE_NAME < "$INPUT_FILE" > "$TEMPORARY_FILE_NAME"; } 2>&1 );
                OUTPUT_DIFFERENCE=$(diff "$OUTPUT_FILE" "$TEMPORARY_FILE_NAME");
                if [ ! $? -eq 0 ];
                then
                    if [ "$DETAILED_TEST_OUTPUT" = true ];
                    then
                        WARNING_MESSAGE "FAILED, $TIME_SPENT";
                    else
                        WARNING_MESSAGE "$SUCCESSFUL_TEST_COUNT/$MAXIMUM_TEST_COUNT, failed on $INPUT_FILE";
                    fi;
                    SEPARATOR;
                    cat "$INPUT_FILE";
                    SEPARATOR;
                    echo "$OUTPUT_DIFFERENCE";
                    SEPARATOR;
                    exit 1;
                else
                    if [ "$DETAILED_TEST_OUTPUT" = true ];
                    then
                        SUCCESS_MESSAGE "OK, $TIME_SPENT";
                    fi;
                fi;
                SUCCESSFUL_TEST_COUNT=$((SUCCESSFUL_TEST_COUNT+1));
            fi;
        done;
        if [ "$DETAILED_TEST_OUTPUT" = false ];
        then
            SUCCESS_MESSAGE "$SUCCESSFUL_TEST_COUNT/$MAXIMUM_TEST_COUNT";
        fi;
    fi;
} ;

COMPILE () {
    echo -en "$1 Compiling source code ... ";
    if [ ! -f $SOURCE_FILE_NAME ];
    then
        WARNING_MESSAGE "NOT FOUND";
        exit 1;
    fi;
    if [ -f $COMPILED_FILE_NAME ];
    then
        md5sum "$SOURCE_FILE_NAME" > "$TEMPORARY_FILE_NAME";
        md5sum "$COMPILED_FILE_NAME" >> "$TEMPORARY_FILE_NAME";
    fi;
    diff "$HASH_FILE_NAME" "$TEMPORARY_FILE_NAME" > /dev/null 2> /dev/null;
    if [ ! $? -eq 0 ] || [ ! -f "$COMPILED_FILE_NAME" ];
    then
        g++ -Wall -pedantic "$SOURCE_FILE_NAME" -o "$COMPILED_FILE_NAME" || exit 1;
        if [ $? -eq 0 ];
        then
            SUCCESS_MESSAGE "OK";
        else
            ERROR_MESSAGE "FAILED";
        fi;
        md5sum "$SOURCE_FILE_NAME" > "$HASH_FILE_NAME";
        md5sum "$COMPILED_FILE_NAME" >> "$HASH_FILE_NAME";
    else
        SUCCESS_MESSAGE "SKIPPED";
    fi;
} ;

RUN_TESTS () {
    cd "$2" || exit 1;
    PREFIX="$(GET_PREFIX_COLOR "$1")$2${NO_COLOR}:";
    COMPILE "$PREFIX";
    for FOLDER in *;
    do
        if [ -d "$FOLDER" ];
        then
            TEST_CASE "$PREFIX" "$FOLDER" "$INPUT_FILE_SUFFIX" "$OUTPUT_FILE_SUFFIX";
        fi;
    done;
    cd ..;
} ;

TEST_ALL_FOLDERS () {
    COUNT=1
    for FOLDER in *;
    do
        if [ -d "$FOLDER" ];
        then
            RUN_TESTS $COUNT "$FOLDER";
        fi;
        COUNT=$((COUNT+1));
    done;
} ;

TEST_LATEST_FOLDER () {
    FOLDER_COUNT=$(ls -d * 2>/dev/null | wc -l);
    if [ "$FOLDER_COUNT" -eq 0 ];
    then
        ERROR_MESSAGE "No folder found!";
        exit 1;
    fi;
    LATEST=$(ls -td * | head -1);
    RUN_TESTS 1 "$LATEST";
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
} ;

while :; do
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
        --)
            shift;
            break;
            ;;
        -?*)
            ERROR_MESSAGE "Unknown option: '$1', use '--help' to get list of usable options";
            exit 1;
            ;;
        *)
            break;
    esac
    shift;
done

if $LATEST_FOLDER_ONLY;
then
    TEST_LATEST_FOLDER;
else
    TEST_ALL_FOLDERS;
fi;