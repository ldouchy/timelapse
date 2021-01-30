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
WORKINGFOLDER=unset
DEBUG=0

function usage () {
  echo "Usage: buildTimelapse [ -s | --syncfile ] [ -t | --timestamp ] [ -c | --createvideo ] [ -p | --progressoverlay ]
                        [ -f | --framerate <NUMBER> ] 
                        [ -n | --night ] | [ -d | --day ] | [ -a | --all ]
                        [ -v | --verbose ]
                        [ -h | --help ]
                        [ -w | --workingfolder <foldername>]"
  exit 0
}

PARSED_ARGUMENTS=$( getopt -a -n \
                      buildTimelapse \
                        -o stcpndahv,w:f: \
                        --long syncfile,timestamp,createvideo,progressoverlay,night,day,all,verbose,help,workingfolder:,framerate: \
                        -- \
                        "$@" )

VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]
then
  usage
fi

echo "PARSED_ARGUMENTS is $PARSED_ARGUMENTS"
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
    -w | --workingfolder)       WORKINGFOLDER="$2"      ; shift 2 ;;
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

if [[ ${DEBUG} -eq 1 ]]
then
  echo "SYNCFILE             : ${SYNCFILE}"
  echo "TIMESTAMPCREATION    : ${TIMESTAMPCREATION}"
  echo "VIDEOPROCESSING      : ${VIDEOPROCESSING}"
  echo "PROGRESSOVERLAY      : ${PROGRESSOVERLAY}"
  echo "FRAMERATE            : ${FRAMERATE}"
  echo "VIDEOTYPE            : ${VIDEOTYPE}"
  echo "WORKINGFOLDER        : ${WORKINGFOLDER}"
  echo "DEBUG                : ${DEBUG}"
  echo "Parameters remaining : $@"
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

  LOGLEVEL="-loglevel quiet"
  if [[ ${DEBUG} -eq 1 ]]
  then
    LOGLEVEL=""
  fi

  FRAMERATE=$2      ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprocessor - FRAMERATE: ${FRAMERATE}" ; fi
  FILENAME=$3       ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprocessor - FILENAME: ${FILENAME}" ; fi
  DATEPROCESSED=$4  ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprocessor - DATEPROCESSED: ${DATEPROCESSED}" ; fi

  ffmpeg \
      -y \
      ${LOGLEVEL} \
      -framerate ${FRAMERATE} \
      -f image2pipe \
      -vcodec mjpeg \
      -i - \
      -s:v 1440x1080 \
      -c:v libx264 \
      -crf 17 \
      -pix_fmt yuvj420p \
      ${FILENAME}
}

function videoofthedaycreation () {
  
  FR=$1
  FOLDERPATH=$2
  VIDEOTYPE=$3
  FILENAME=$4         ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoofthedaycreation - FILENAME: ${FILENAME}" ; fi
  DATEPROCESSED=${5}

  echo "Processing video of the day from ${FOLDERPATH}"

  # select files larger than, allow to remove dark images
  if [[ ${VIDEOTYPE} == "DAY" ]]
  then
    dayfileselection | videoprocessor ${LOGLEVEL} ${FR} ${FILENAME} ${DATEPROCESSED}
  elif [[ ${VIDEOTYPE} == "NIGHT" ]]
  then
    nightfileselection | videoprocessor ${LOGLEVEL} ${FR} ${FILENAME} ${DATEPROCESSED}
  elif [[ ${VIDEOTYPE} == "ALL" ]]
  then
    cat *.jpg | videoprocessor ${LOGLEVEL} ${FR} ${FILENAME} ${DATEPROCESSED}
  fi

  echo "Video processing completed"
  echo "rsync -avhH --stats --progress zeus:${FOLDERPATH}/${FILENAME} ./"
}

function videoprogressbaroverlay () {
  FILENAME=$1
  if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprogressbaroverlay - FILENAME: ${FILENAME}" ; fi

  LOGLEVEL="-loglevel quiet"
  if [[ ${DEBUG} -eq 1 ]]
  then
    LOGLEVEL=""
  fi

  WIDTH=$( ffprobe -v error -show_entries stream=width -of default=noprint_wrappers=1 ${FILENAME} | awk -F= '{print $2}' )
  if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprogressbaroverlay - WIDTH: ${WIDTH}" ; fi
  
  DURATION=$( ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 ${FILENAME} | awk -F= '{print $2}' )
  if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprogressbaroverlay - DURATION: ${DURATION}" ; fi

  ffmpeg \
    -y \
    ${LOGLEVEL} \
    -i ${FILENAME} \
    -filter_complex "color=c=red:s=${WIDTH}x5[bar];[0][bar]overlay=-w+(w/${DURATION})*t:H-h:shortest=1" \
    -c:a \
    copy \
    PB-${FILENAME}

  echo "Progress bar added"
  echo "rsync -avhH --stats --progress zeus:${FOLDERPATH}/PB-${FILENAME} ./"
}

function addtimestamp () {

  PICTURE=$1

  FILEDATE=$(echo ${PICTURE} | awk -F\. '{print $1}')
  TIMESTAMP=$(echo ${FILEDATE/T/} | awk -F\+ '{print $1}' | sed 's/.\{2\}$/.&/')

  if [ -f ${FILEDATE}.jpg ]
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
# Global variables setup
# 
###

FOLDERPATH=/mnt/dnas/pi/bristol/${WORKINGFOLDER}
if [[ ${DEBUG} -eq 1 ]] ; then echo "FOLDERPATH: ${FOLDERPATH}" ; fi

DATEPROCESSED=$( echo ${WORKINGFOLDER} | awk -F_ '{print $2}' )
if [[ ${DEBUG} -eq 1 ]] ; then echo "DATEPROCESSED: ${DATEPROCESSED}" ; fi

FILENAME="TL-${FRAMERATE}-${VIDEOTYPE}-${DATEPROCESSED}.mp4"
if [[ ${DEBUG} -eq 1 ]] ; then echo "FILENAME: ${FILENAME}" ; fi


###
#
# Create working folder and set mod. 
# Usefull when working with different users sharing the same group
#
###

mkdir -p ${FOLDERPATH}
chmod g+w ${FOLDERPATH}

if [ ! -d "${FOLDERPATH}" ]
then
  echo "Folder ${FOLDERPATH} does not exist"
  exit 1
fi

cd ${FOLDERPATH}


###
#
# Sync folder of the day
#
###

if [[ ${SYNCFILE} -eq 1 ]]
then
  echo "Synchronise folder ${WORKINGFOLDER}"

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
      /mnt/dnas/pi/bristol/raw/ ${FOLDERPATH}/

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
    cd ${FOLDERPATH}
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
  videoofthedaycreation ${FRAMERATE} ${FOLDERPATH} ${VIDEOTYPE} ${FILENAME} ${DATEPROCESSED}
fi


###
#
# Add progress bar at the botton of the video
#
###

if [[ ${PROGRESSOVERLAY} -eq 1 ]]
then
  videoprogressbaroverlay ${FILENAME}
fi

exit 0
