#!/usr/bin/bash

###
#
# Script argument management
#
###

# Default values
SYNCFILE=0
TIMESTAMPCREATION=0
VIDEOPROCESSING=0
PROGRESSOVERLAY=0
FRAMERATE=30
VIDEOTYPE="ALL"
INPUTPATH=unset
SOURCEPATH="/mnt/dnas/pi/bristol"
SOURCEFOLDER="raw"
OUTPUTPATH=unset
TARGETPATH=unset
TARGETFOLDER=unset
DEBUG=0

function usage () {
  echo "Usage: buildTimelapse [ -s | --syncfile ] [ -t | --timestamp ] [ -c | --createvideo ] [ -p | --progressoverlay ]
                        [ -f | --framerate <NUMBER> ] 
                        [ -n | --night ] [ -d | --day ] [ -a | --all ]
                        [ -i | --input </path/folder>]
                        [ -o | --output </path/folder>]
                        [ -v | --verbose ]
                        [ -h | --help ]"
  exit 0
}

PARSED_ARGUMENTS=$( getopt -a \
                      --name buildTimelapse \
                      -o stcpndavh,f:i:o: \
                      --long syncfile,timestamp,createvideo,progressoverlay,night,day,all,input:,output:,verbose,help,framerate: \
                      -- \
                      "$@" )

VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]
then
  usage
fi

# getopt debug, can't be managed via -h
# echo "PARSED_ARGUMENTS is $PARSED_ARGUMENTS"
eval set -- "$PARSED_ARGUMENTS"
while :
do
  case "$1" in
    -h | --help)                HELP=1                  ; usage   ;;
    -s | --syncfiles)           SYNCFILE=1              ; shift   ;;
    -t | --timestamp)           TIMESTAMPCREATION=1     ; shift   ;;
    -c | --createvideo)         VIDEOPROCESSING=1       ; shift   ;;
    -p | --progressoverlay)     PROGRESSOVERLAY=1       ; shift   ;;
    -f | --framerate)           FRAMERATE="$2"          ; shift 2 ;;
    -i | --input)               INPUTPATH="$2"          ; shift 2 ;;
    -o | --output)              OUTPUTPATH="$2"         ; shift 2 ;;
    -n | --night)               VIDEOTYPE="NIGHT"       ; shift   ;;
    -d | --day)                 VIDEOTYPE="DAY"         ; shift   ;;
    -a | --all)                 VIDEOTYPE="ALL"         ; shift   ;;
    -v | --verbose)             DEBUG=1                 ; shift   ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *) echo "Unexpected option: $1 - this should not happen."
       usage ;;
  esac
done

if [[ ! -d "${INPUTPATH}" ]]
then
  echo "Input folder does not exist"
  exit 1
fi

if [[ ${OUTPUTPATH} == "unset" ]]
then
  echo "OUTPUTPATH folder is mandatory"
  usage
fi

# Split input and reconstruct it to ensure consistency
SOURCEPATH=$(dirname "${INPUTPATH}")
SOURCEFOLDER=$(basename "${INPUTPATH}")
INPUTPATH=${SOURCEPATH}/${SOURCEFOLDER}

# Split output and reconstruct it to ensure consistency
TARGETPATH=$(dirname "${OUTPUTPATH}")
TARGETFOLDER=$(basename "${OUTPUTPATH}")
OUTPUTPATH="${TARGETPATH}/${TARGETFOLDER}"

DATEPROCESSED=$( echo ${TARGETFOLDER} | awk -F_ '{print $2}' )

FILENAME="TL-${FRAMERATE}-${VIDEOTYPE}-${DATEPROCESSED}.mp4"

if [[ ${DEBUG} -eq 1 ]]
then
  echo "Arguments passed to the command line/default values:
  SYNCFILE             : ${SYNCFILE}
  TIMESTAMPCREATION    : ${TIMESTAMPCREATION}
  VIDEOPROCESSING      : ${VIDEOPROCESSING}
  PROGRESSOVERLAY      : ${PROGRESSOVERLAY}
  FRAMERATE            : ${FRAMERATE}
  VIDEOTYPE            : ${VIDEOTYPE}
  DEBUG                : ${DEBUG}
  Parameters remaining : $@

Computed variables   :
  INPUTPATH            : ${INPUTPATH}
  SOURCEPATH           : ${SOURCEPATH}
  SOURCEFOLDER         : ${SOURCEFOLDER}
  OUTPUTPATH           : ${OUTPUTPATH}
  TARGETPATH           : ${TARGETPATH}
  TARGETFOLDER         : ${TARGETFOLDER}
  DATEPROCESSED        : ${DATEPROCESSED}
  FILENAME             : ${FILENAME}"
fi


###
#
# Functions
#
###

function dayfileselection () {

  find ./ -name "*.jpg" -type f -size +800k -print0 | sort -z | xargs -0 cat
}

function nightfileselection () {

  find ./ -name "*.jpg" -type f -size -800k -print0 | sort -z | xargs -0 cat
}

function videoprocessor () {

  FRAMERATE=${1}      ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprocessor - FRAMERATE: ${FRAMERATE}" ; fi
  OUTPUTPATH=${2}     ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprocessor - OUTPUTPATH: ${OUTPUTPATH}" ; fi
  FILENAME=${3}       ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprocessor - FILENAME: ${FILENAME}" ; fi

  LOGLEVEL="-loglevel quiet"
  if [[ ${DEBUG} -eq 1 ]]
  then
    LOGLEVEL=""
  fi

  ffmpeg \
      -y \
      ${LOGLEVEL} \
      -stats \
      -framerate ${FRAMERATE} \
      -f image2pipe \
      -vcodec mjpeg \
      -i - \
      -s:v 1440x1080 \
      -c:v libx264 \
      -crf 17 \
      -pix_fmt yuvj420p \
      ${OUTPUTPATH}/${FILENAME}
}

function videoofthedaycreation () {
  
  FRAMERATE=${1}        ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoofthedaycreation - FRAMERATE: ${FRAMERATE}" ; fi
  VIDEOTYPE=${2}        ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoofthedaycreation - VIDEOTYPE: ${VIDEOTYPE}" ; fi
  OUTPUTPATH=${3}       ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoofthedaycreation - OUTPUTPATH: ${OUTPUTPATH}" ; fi
  FILENAME=${4}         ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoofthedaycreation - FILENAME: ${FILENAME}" ; fi
  DATEPROCESSED=${5}    ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoofthedaycreation - DATEPROCESSED: ${DATEPROCESSED}" ; fi

  echo "Processing video of the day from $(pwd)"

  # select files larger than, allow to remove dark images
  if [[ ${VIDEOTYPE} == "DAY" ]]
  then
    dayfileselection | videoprocessor ${FRAMERATE} ${OUTPUTPATH} ${FILENAME} ${DATEPROCESSED}
  elif [[ ${VIDEOTYPE} == "NIGHT" ]]
  then
    nightfileselection | videoprocessor ${FRAMERATE} ${OUTPUTPATH} ${FILENAME} ${DATEPROCESSED}
  elif [[ ${VIDEOTYPE} == "ALL" ]]
  then
    cat *.jpg | videoprocessor ${FRAMERATE} ${OUTPUTPATH} ${FILENAME} ${DATEPROCESSED}
  fi

  echo "Video processing completed"
  echo "rsync -avhH --stats --progress zeus:${OUTPUTPATH}/${FILENAME} ./"
}

function videoprogressbaroverlay () {

  OUTPUTPATH=${1} ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprogressbaroverlay - OUTPUTPATH: ${OUTPUTPATH}" ; fi
  FILENAME=${2}   ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprogressbaroverlay - FILENAME: ${FILENAME}" ; fi

  LOGLEVEL="-loglevel quiet"
  if [[ ${DEBUG} -eq 1 ]]
  then
    LOGLEVEL=""
  fi

  WIDTH=$( ffprobe -v error -show_entries stream=width -of default=noprint_wrappers=1 ${OUTPUTPATH}/${FILENAME} | awk -F= '{print $2}' )
  if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprogressbaroverlay - WIDTH: ${WIDTH}" ; fi
  
  DURATION=$( ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 ${OUTPUTPATH}/${FILENAME} | awk -F= '{print $2}' )
  if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprogressbaroverlay - DURATION: ${DURATION}" ; fi

  ffmpeg \
    -y \
    ${LOGLEVEL} \
    -stats \
    -i ${OUTPUTPATH}/${FILENAME} \
    -filter_complex "color=c=red:s=${WIDTH}x5[bar];[0][bar]overlay=-w+(w/${DURATION})*t:H-h:shortest=1" \
    -c:a \
    copy \
    ${OUTPUTPATH}/PB-${FILENAME}

  echo "Progress bar added"
  echo "rsync -avhH --stats --progress zeus:${OUTPUTPATH}/PB-${FILENAME} ./"
}

function addtimestamp () {

  PICTURE=$1

  FILEDATE=$(echo ${PICTURE} | awk -F\. '{print $1}')
  TIMESTAMP=$(echo ${FILEDATE/T/} | awk -F\+ '{print $1}' | sed 's/.\{2\}$/.&/')

  if [[ -f ${FILEDATE}.jpg ]]
  then
    touch -t ${TIMESTAMP} ${FILEDATE}.jpg
    return
  fi

  montage \
    -label "${FILEDATE}" ${PICTURE} \
    -pointsize 60 \
    -gravity Center \
    -geometry +0+0 \
    ${FILEDATE}.jpg
  
  touch -t ${TIMESTAMP} ${FILEDATE}.jpg
}


###
#
# Create working folder and set mod. 
# Usefull when working with different users sharing the same group
#
###

mkdir -p ${OUTPUTPATH}
chmod g+w ${OUTPUTPATH}

if [[ ! -d "${OUTPUTPATH}" ]]
then
  echo "Folder ${OUTPUTPATH} does not exist"
  exit 1
fi

cd ${INPUTPATH}


###
#
# Sync folder of the day
#
###

if [[ ${SYNCFILE} -eq 1 ]]
then
  echo "Synchronise folder ${TARGETFOLDER}"

  LOGLEVEL="--quiet"
  if [[ ${DEBUG} -eq 1 ]]
  then
    LOGLEVEL="--progress"
  fi

  rsync -avhH \
      --stats \
      --include="*/" \
      --include="${DATEPROCESSED}T*" \
      --exclude="*" \
      ${LOGLEVEL} \
      ${INPUTPATH}/ ${OUTPUTPATH}/

  echo "Synchronisation completed"
fi


###
#
# Image processing to add date at the bottom
#
###

if [[ ${TIMESTAMPCREATION} -eq 1 ]]
then
  echo "Timestamping images"

  if command -v parallel &> /dev/null
  then 
    export -f addtimestamp
    ls *.jpeg | parallel --bar -j20 addtimestamp ${PICTURE}
  else
    for PICTURE in $( ls *.jpeg )
    do
      addtimestamp ${PICTURE}
    done
  fi

  echo "Timestamping completed"
fi


###
#
# Video creation
#
###

if [[ ${VIDEOPROCESSING} -eq 1 ]]
then
  videoofthedaycreation ${FRAMERATE} ${VIDEOTYPE} ${OUTPUTPATH} ${FILENAME} ${DATEPROCESSED} 
fi


###
#
# Add progress bar at the botton of the video
#
###

if [[ ${PROGRESSOVERLAY} -eq 1 ]]
then
  videoprogressbaroverlay ${OUTPUTPATH} ${FILENAME}
fi

exit 0
