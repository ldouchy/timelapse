#!/usr/bin/bash

###
#
# Functions
#
###

dayfileselection () {
  find ./ -name "*.jpg" -type f -size +800k -print0 | sort -z | xargs -0 cat
}

nightfileselection () {
  find ./ -name "*.jpg" -type f -size -800k -print0 | sort -z | xargs -0 cat
}

videoprocessor () {
  LOGLEVEL="-loglevel quiet"
  if [[ ${DEBUG} -eq 1 ]]
  then
    LOGLEVEL=""
  fi

  FRAMERATE=$2  ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprocessor - FRAMERATE: ${FRAMERATE}" ; fi
  FILENAME=$3   ; if [[ ${DEBUG} -eq 1 ]] ; then echo "videoprocessor - FILENAME: ${FILENAME}" ; fi

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
      -pix_fmt yuv420p \
      ${FILENAME}
}

videoofthedaycreation () {
  
  FR=$1
  FOLDERPATH=$2
  VIDEOTYPE=$3



  DATEPROCESSED=$( echo ${FOLDERPATH} | awk -F_ '{print $2}' )
  echo "Processing video of the day from ${FOLDERPATH}"
  FILENAME="${FOLDERPATH}/TL-${FR}-${VIDEOTYPE}-${DATEPROCESSED}.mp4"

  # select files larger than, allow to remove dark images
  if [[ ${VIDEOTYPE} == "DAY" ]]
  then
    dayfileselection | videoprocessor ${LOGLEVEL} ${FR} ${FILENAME}
  elif [[ ${VIDEOTYPE} == "NIGHT" ]]
  then
    nightfileselection | videoprocessor ${LOGLEVEL} ${FR} ${FILENAME}
  elif [[ ${VIDEOTYPE} == "ALL" ]]
  then
    cat *.jpg | videoprocessor ${LOGLEVEL} ${FR} ${FILENAME}
  fi

  echo "Video processing completed"
  echo "rsync -avhH --stats --progress zeus:${FILENAME} ./"
}

# $1: 
addtimestamp () {

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
# Global variables setup and image prep
# 
###

# Set some default values:
SYNCFILE=0
TIMESTAMPCREATION=0
VIDEOPROCESSING=0
FRAMERATE=30
VIDEOTYPE="ALL"
DEBUG=0
WORKINGFOLDER=unset

usage()
{
  echo "Usage: buildTimelapse [ -s | --syncfile ] [ -t | --timestamp ] [ -c | --createvideo ]
                        [ -f | --framerate <NUMBER> ] 
                        [ -n | --night ] | [ -d | --day ] | [ -a | --all ]
                        [ -v | --verbose ]
                        [ -w | --workingfolder <foldername>]"
  exit 2
}

PARSED_ARGUMENTS=$(getopt -a -n buildTimelapse -o stcndav,w:f: --long syncfile,timestamp,createvideo,night,day,all,verbose,workingfolder:,framerate: -- "$@")
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
    -s | --syncfiles)           SYNCFILE=1              ; shift   ;;
    -t | --timestamp)           TIMESTAMPCREATION=1     ; shift   ;;
    -c | --createvideo)         VIDEOPROCESSING=1       ; shift   ;;
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

echo "SYNCFILE             : ${SYNCFILE}"
echo "TIMESTAMPCREATION    : ${TIMESTAMPCREATION}"
echo "VIDEOPROCESSING      : ${VIDEOPROCESSING}"
echo "FRAMERATE            : ${FRAMERATE}"
echo "VIDEOTYPE            : ${VIDEOTYPE}"
echo "WORKINGFOLDER        : ${WORKINGFOLDER}"
echo "DEBUG                : ${DEBUG}"
echo "Parameters remaining : $@"

ROOT=/mnt/dnas/pi/bristol/${WORKINGFOLDER}

###
#
# Sync folder of the day
#
###

DATEPROCESSED=$( echo ${WORKINGFOLDER} | awk -F_ '{print $2}' )
if [[ ${DEBUG} -eq 1 ]] ; then echo "Processing video of the day from ${WORKINGFOLDER}" ; fi

mkdir -p ${ROOT}
chmod g+w ${ROOT}

if [ ! -d "${ROOT}" ]
then
  echo "Folder ${ROOT} does not exist"
  exit 1
fi

LOGLEVEL="--quiet"
if [[ ${DEBUG} -eq 1 ]]
then
  LOGLEVEL="--progress"
fi

if [[ ${SYNCFILE} -eq 1 ]]
then
  echo "Synchronise folder ${WORKINGFOLDER}"

  rsync -avhH \
      --stats \
      --include="*/" \
      --include="${DATEPROCESSED}T*" \
      --exclude="*" \
      ${LOGLEVEL} \
      /mnt/dnas/pi/bristol/raw/ ${ROOT}/

  echo "Synchronisation completed"
fi

cd ${ROOT}
if [[ ${DEBUG} -eq 1 ]] ; then echo "Working path: ${ROOT}" ; fi

###
#
# Image processing to add date at the bottom and video creation
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
    cd ${ROOT}
    for PICTURE in $( ls *.jpeg )
    do
      addtimestamp ${PICTURE}
    done
  fi

  echo "Timestamping completed"
fi

###
#
# Video creation, high quality then timestamped
#
###

if [[ ${VIDEOPROCESSING} -eq 1 ]]
then
  videoofthedaycreation ${FRAMERATE} ${ROOT} ${VIDEOTYPE}
fi

exit 0