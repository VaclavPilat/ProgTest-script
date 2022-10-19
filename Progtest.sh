SOURCE_FILE_NAME="Main.c";
COMPILED_FILE_NAME="a.out";
TEMPORARY_FILE_NAME="/tmp/tmp.txt";
HASH_FILE_NAME="hash.txt";
INPUT_FILE_SUFFIX="_in.txt";
OUTPUT_FILE_SUFFIX="_out.txt";

SEPARATOR () {
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -;
} ;

TESTCASE () {
  if [ -d $2 ];
  then
    SUCCESSFUL_TEST_COUNT=0;
    MAXIMUM_TEST_COUNT=`echo "$2/"*"$3" | wc -w`;
    for INPUT_FILE in "$2/"*"$3";
    do
      OUTPUT_FILE=${INPUT_FILE%$3}$4;
      ./$COMPILED_FILE_NAME < "$INPUT_FILE" > "$TEMPORARY_FILE_NAME" || exit 1;
      OUTPUT_DIFFERENCE=`diff "$OUTPUT_FILE" "$TEMPORARY_FILE_NAME"`;
      if [ ! $? -eq 0 ];
      then
        echo "$1: Successfully tried $SUCCESSFUL_TEST_COUNT/$MAXIMUM_TEST_COUNT inputs.";
        echo "$1: Failed test on $INPUT_FILE";
        SEPARATOR;
        cat "$INPUT_FILE";
        SEPARATOR;
        echo "$OUTPUT_DIFFERENCE";
        SEPARATOR;
        exit 1;
      fi;
      SUCCESSFUL_TEST_COUNT=$((SUCCESSFUL_TEST_COUNT+1));
    done;
    echo "$1: Successfully tried $SUCCESSFUL_TEST_COUNT $2 inputs.";
  fi;
} ;

COMPILE () {
  if [ -f $COMPILED_FILE_NAME ];
  then
    md5sum "$SOURCE_FILE_NAME" > "$TEMPORARY_FILE_NAME";
    md5sum "$COMPILED_FILE_NAME" >> "$TEMPORARY_FILE_NAME";
  fi;
  diff "$HASH_FILE_NAME" "$TEMPORARY_FILE_NAME" > /dev/null 2> /dev/null;
  if [ ! $? -eq 0 ] || [ ! -f "$COMPILED_FILE_NAME" ];
  then
    echo "$1: Compiling source code ...";
    g++ -Wall -pedantic "$SOURCE_FILE_NAME" -o "$COMPILED_FILE_NAME" || exit 1;
    md5sum "$SOURCE_FILE_NAME" > "$HASH_FILE_NAME";
    md5sum "$COMPILED_FILE_NAME" >> "$HASH_FILE_NAME";
  else
    echo "$1: Skipped compilation (not needed).";
  fi;
} ;

RUNTESTS () {
  cd $1;
  COMPILE $1;
  echo "$1: Testing input files ...";
  for FOLDER in *;
  do
    TESTCASE "$1" "$FOLDER" "$INPUT_FILE_SUFFIX" "$OUTPUT_FILE_SUFFIX";
  done;
  cd ..;
} ;

for FOLDER in *;
do
  if [ -d $FOLDER ];
  then
   RUNTESTS $FOLDER;
  fi;
done;