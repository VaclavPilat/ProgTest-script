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

SUCCESS_MESSAGE () {
    echo -e "${GREEN_BOLD_COLOR}${1}${NO_COLOR}";
}

WARNING_MESSAGE () {
    echo -e "${RED_BOLD_COLOR}${1}${NO_COLOR}";
}

WARNING_MESSAGE () {
    echo -e "${YELLOW_BOLD_COLOR}${1}${NO_COLOR}";
}

SEPARATOR () {
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -;
} ;

GETCOLOR () {
    echo -e "\033[0;3$((1 + $1 % 5))m";
} ;

TESTCASE () {
    if [ -d $2 ];
    then
        echo -n "$PREFIX Testing $2 inputs ... ";
        SUCCESSFUL_TEST_COUNT=0;
        MAXIMUM_TEST_COUNT=`echo "$2/"*"$3" | wc -w`;
        for INPUT_FILE in "$2/"*"$3";
        do
            if [ -f $INPUT_FILE ];
            then
                OUTPUT_FILE=${INPUT_FILE%$3}$4;
                ./$COMPILED_FILE_NAME < "$INPUT_FILE" > "$TEMPORARY_FILE_NAME" || exit 1;
                OUTPUT_DIFFERENCE=`diff "$OUTPUT_FILE" "$TEMPORARY_FILE_NAME"`;
                if [ ! $? -eq 0 ];
                then
                    WARNING_MESSAGE "$SUCCESSFUL_TEST_COUNT/$MAXIMUM_TEST_COUNT, failed on $INPUT_FILE";
                    SEPARATOR;
                    cat "$INPUT_FILE";
                    SEPARATOR;
                    echo "$OUTPUT_DIFFERENCE";
                    SEPARATOR;
                    exit 1;
                fi;
                SUCCESSFUL_TEST_COUNT=$((SUCCESSFUL_TEST_COUNT+1));
            fi;
        done;
        SUCCESS_MESSAGE "$SUCCESSFUL_TEST_COUNT/$MAXIMUM_TEST_COUNT";
    fi;
} ;

COMPILE () {
    echo -n "$1 Compiling source code ... ";
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

RUNTESTS () {
    cd $2;
    PREFIX="$(GETCOLOR $1)$2$(echo -e '\033[0m'):";
    COMPILE $PREFIX;
    for FOLDER in *;
    do
        if [ -d $FOLDER ];
        then
            TESTCASE "$PREFIX" "$FOLDER" "$INPUT_FILE_SUFFIX" "$OUTPUT_FILE_SUFFIX";
        fi;
    done;
    cd ..;
} ;

COUNT=1
for FOLDER in *;
do
    if [ -d $FOLDER ];
    then
        RUNTESTS $COUNT $FOLDER;
    fi;
    COUNT=$((COUNT+1));
done;