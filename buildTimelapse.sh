#!/usr/bin/bash

# buildTimelapse.sh - An opinionated time-lapse creation tool
# Copyright (C) 2021  Laurent DOUCHY
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

###
#
# Script argument management
#
###

# Default values
START=unset
END=unset
TIMESTAMPCREATION=0
VIDEOPROCESSING=0
PROGRESSOVERLAY=0
FRAMERATE=30
INPUTPATH=unset
SOURCEPATH=unset
SOURCEFOLDER=unset
OUTPUTPATH=unset
TARGETPATH=unset
TARGETFOLDER=unset
IMAGELIST=()
DEBUG=0


###
#
# Function dedicated to the argument processing
#
###

function mandatoryvar () {
  VARIABLE=${1}
  if [[ ${!VARIABLE} == "unset" ]]
  then
    echo "Argument ${VARIABLE} is mandatory"
    echo
    usage
  fi
}

function usage () {
  echo "Usage: buildTimelapse [ -i | --input </path/folder>] [ -o | --output </path/folder>] [ -s | --start YYYY-MM-DD HH:MM:SS] [ -e | --end YYYY-MM-DD HH:MM:SS] 
  [ -t | --timestamp ] [ -c | --createvideo ] [ -p | --progressoverlay ]
  [ -f | --framerate <NUMBER> ] 
  [ -v | --verbose ]
  [ -h | --help ]"
  exit 0
}

PARSED_ARGUMENTS=$( getopt -a \
                      --name buildTimelapse \
                      -o tcpvh,s:e:f:i:o: \
                      --long timestamp,createvideo,progressoverlay,input:,output:,start:,end:,verbose,help,framerate: \
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

    -c | --createvideo)         VIDEOPROCESSING=1       ; shift   ;;

    # Timestamp video requires video creation
    -t | --timestamp)           TIMESTAMPCREATION=1; 
                                VIDEOPROCESSING=1       ; shift   ;;

    # Overlay video requires video cration
    -p | --progressoverlay)     PROGRESSOVERLAY=1 ; 
                                VIDEOPROCESSING=1       ; shift   ;;
    
    -s | --start)               START="${2}"            ; shift 2 ;;
    -e | --end)                 END="${2}"              ; shift 2 ;;
    -f | --framerate)           FRAMERATE="${2}"        ; shift 2 ;;
    -i | --input)               INPUTPATH="${2}"        ; shift 2 ;;
    -o | --output)              OUTPUTPATH="${2}"       ; shift 2 ;;

    # Verbosity control
    -v | --verbose)             DEBUG=1                 ; shift   ;;
    --vv )                      DEBUG=2                 ; shift   ;;
    --vvv )                     DEBUG=3                 ; shift   ;;

    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *) echo "Unexpected option: $1 - this should not happen."
       usage ;;
  esac
done

# Check if mandatory arguments are provided
for VARIABLE in "INPUTPATH" "OUTPUTPATH" "START" "END"
do
  mandatoryvar ${VARIABLE}
done

# Split input and reconstruct it to ensure consistency
SOURCEPATH=$(dirname "${INPUTPATH}")
SOURCEFOLDER=$(basename "${INPUTPATH}")
INPUTPATH=${SOURCEPATH}/${SOURCEFOLDER}

# Split output and reconstruct it to ensure consistency
TARGETPATH=$(dirname "${OUTPUTPATH}")
TARGETFOLDER=$(basename "${OUTPUTPATH}")
OUTPUTPATH="${TARGETPATH}/${TARGETFOLDER}"

# Test date parameters
STARTEPOCH=$(date --date="${START}" +%s 2>/dev/null)
if [[ $? != "0" ]]
then
  echo "--start must be of form YYYY-MM-DD HH:MM:SS"
  exit 1
fi

ENDEPOCH=$(date --date="${END}" +%s 2>/dev/null)
if [[ $? != "0" ]]
then
  echo "--end must be of form YYYY-MM-DD HH:MM:SS"
  exit 1
fi

if [[ ${STARTEPOCH} -ge ${ENDEPOCH}  ]]
then
  echo "start date must be earlier than end date"
fi

# Create array of files to be processed
IMAGELIST=( $( find ${INPUTPATH} -type f -name "*.jpeg" -newermt "${START}" -not -newermt "${END}" ) )

# Sort array - not needed just in case it's required in the future
IFS=$'\n' IMAGELIST=($(sort <<<"${IMAGELIST[*]}")); unset IFS

if [[ ${#IMAGELIST[@]} -le "${FRAMERATE}" ]]
then
  echo "Video is less than a second long. Select more files or decrease the framerate"
  exit 1
else
  if [[ ${DEBUG} -ge 2 ]]
  then
    echo "${#IMAGELIST[@]} image(s) selected"
    printf '%s\n' "${IMAGELIST[@]}"
  fi
fi

URAN=$( cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 8 | head -n 1 )
FILENAME="TL-${FRAMERATE}-${URAN}.mp4"

if [[ ${DEBUG} -ge 1 ]]
then
  echo "Arguments passed to the command line/default values:
  TIMESTAMPCREATION    : ${TIMESTAMPCREATION}
  VIDEOPROCESSING      : ${VIDEOPROCESSING}
  PROGRESSOVERLAY      : ${PROGRESSOVERLAY}
  FRAMERATE            : ${FRAMERATE}
  DEBUG                : ${DEBUG}
  Parameters remaining : $@

Computed variables   :
  INPUTPATH            : ${INPUTPATH}
  SOURCEPATH           : ${SOURCEPATH}
  SOURCEFOLDER         : ${SOURCEFOLDER}
  OUTPUTPATH           : ${OUTPUTPATH}
  TARGETPATH           : ${TARGETPATH}
  TARGETFOLDER         : ${TARGETFOLDER}
  IMAGELIST            : ${#IMAGELIST[@]} images selected
  FILENAME             : ${FILENAME}"
fi


###
#
# Functions
#
###

function videoprocessor () {

  FRAMERATE=${1}      ; if [[ ${DEBUG} -ge 1 ]] ; then echo "videoprocessor - FRAMERATE:  ${FRAMERATE}"    ; fi
  OUTPUTPATH=${2}     ; if [[ ${DEBUG} -ge 1 ]] ; then echo "videoprocessor - OUTPUTPATH: ${OUTPUTPATH}"   ; fi
  FILENAME=${3}       ; if [[ ${DEBUG} -ge 1 ]] ; then echo "videoprocessor - FILENAME:   ${FILENAME}"     ; fi

  LOGLEVEL="-loglevel quiet"
  if [[ ${DEBUG} -ge 1 ]]
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

function videocreation () {
  
  FRAMERATE=${1}    ; if [[ ${DEBUG} -ge 1 ]] ; then echo "videocreation - FRAMERATE: ${FRAMERATE}"    ; fi
  OUTPUTPATH=${2}   ; if [[ ${DEBUG} -ge 1 ]] ; then echo "videocreation - OUTPUTPATH: ${OUTPUTPATH}"  ; fi
  FILENAME=${3}     ; if [[ ${DEBUG} -ge 1 ]] ; then echo "videocreation - FILENAME: ${FILENAME}"      ; fi
  IMAGELIST=${4}    ; if [[ ${DEBUG} -ge 1 ]] ; then echo "videocreation - IMAGELIST: ${#IMAGELIST[@]} images selected" ; fi
  
  if [[ ${DEBUG} -ge 2 ]] ; then echo -n "videocreation - IMAGELIST: " ; printf '%s\n' "${IMAGELIST[@]}"  ; fi

  echo "Processing video $(pwd)"

  cat *.jpeg | videoprocessor ${FRAMERATE} ${OUTPUTPATH} ${FILENAME}

  echo "Video processing completed"
}

function videoprogressbaroverlay () {

  OUTPUTPATH=${1} ; if [[ ${DEBUG} -ge 1 ]] ; then echo "videoprogressbaroverlay - OUTPUTPATH: ${OUTPUTPATH}" ; fi
  FILENAME=${2}   ; if [[ ${DEBUG} -ge 1 ]] ; then echo "videoprogressbaroverlay - FILENAME: ${FILENAME}" ; fi

  LOGLEVEL="-loglevel quiet"
  if [[ ${DEBUG} -ge 1 ]]
  then
    LOGLEVEL=""
  fi

  WIDTH=$( ffprobe -v error -show_entries stream=width -of default=noprint_wrappers=1 ${OUTPUTPATH}/${FILENAME} | awk -F= '{print $2}' )
  if [[ ${DEBUG} -ge 1 ]] ; then echo "videoprogressbaroverlay - WIDTH: ${WIDTH}" ; fi
  
  DURATION=$( ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1 ${OUTPUTPATH}/${FILENAME} | awk -F= '{print $2}' )
  if [[ ${DEBUG} -ge 1 ]] ; then echo "videoprogressbaroverlay - DURATION: ${DURATION}" ; fi

  ffmpeg \
    -y \
    ${LOGLEVEL} \
    -stats \
    -i ${OUTPUTPATH}/${FILENAME} \
    -filter_complex "color=c=red:s=${WIDTH}x5[bar];[0][bar]overlay=-w+(w/${DURATION})*t:H-h:shortest=1" \
    -c:a \
    copy \
    ${OUTPUTPATH}/PB-${FILENAME}

  mv ${OUTPUTPATH}/PB-${FILENAME} ${OUTPUTPATH}/${FILENAME}

  echo "Progress bar added"
}

function addtimestamp () {

  IMAGE=$1          ; if [[ ${DEBUG} -ge 1 ]] ; then echo "addtimestamp - IMAGE: ${IMAGE}" ; fi
  OUTPUTPATH=${2}   ; if [[ ${DEBUG} -ge 1 ]] ; then echo "addtimestamp - OUTPUTPATH: ${OUTPUTPATH}" ; fi

  FILEDATE=$(echo $(basename ${IMAGE}) | awk -F\. '{print $1}')                    ; if [[ ${DEBUG} -eq 1 ]] ; then echo "addtimestamp - FILEDATE: ${FILEDATE}" ; fi

  montage \
    -label "${FILEDATE}" ${IMAGE} \
    -pointsize 60 \
    -gravity Center \
    -geometry +0+0 \
    ${OUTPUTPATH}/${FILEDATE}.jpeg
}


###
#
# Create working folder and set mod. 
# Usefull when working with different users sharing the same group
#
###

if [[ ! -d "${OUTPUTPATH}" ]]
then
  mkdir -p ${OUTPUTPATH}
else
  chmod g+w ${OUTPUTPATH}
fi

if [[ ! -d "${OUTPUTPATH}" ]]
then
  echo "Folder ${OUTPUTPATH} does not exist"
  exit 1
fi

cd ${OUTPUTPATH}


###
#
# Add date at the bottom of the image
#
###

if [[ ${DEBUG} -ge 1 ]] ; then echo "deleting jpeg from ${OUTPUTPATH}" ; fi
rm -rf ${OUTPUTPATH}/*.jpeg

if [[ ${TIMESTAMPCREATION} -eq 1 ]]
then
  echo "Timestamping images"

  if command -v parallel &> /dev/null
  then 
    export -f addtimestamp
    parallel --bar -j20 addtimestamp {} ::: ${IMAGELIST[@]} ::: ${OUTPUTPATH}
  else
    for IMAGE in ${IMAGELIST[@]}
    do
      addtimestamp ${IMAGE} ${OUTPUTPATH}
    done
  fi

else
  if command -v parallel &> /dev/null
  then 
    parallel --bar -j20 cp -p {} ::: ${IMAGELIST[@]} ::: ${OUTPUTPATH}
  else
    for IMAGE in ${IMAGELIST[@]}
    do
      cp -p ${IMAGE} ${OUTPUTPATH}
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
  videocreation ${FRAMERATE} ${OUTPUTPATH} ${FILENAME} ${IMAGELIST} 
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


###
#
# Clean up jpeg files & provide link
#
###

if [[ ${DEBUG} -ge 1 ]] ; then echo "cleaning ${OUTPUTPATH} folder content" ; fi
rm -rf ${OUTPUTPATH}/*.jpeg

if [[ ${VIDEOPROCESSING} -eq 1 ]] || [[ ${PROGRESSOVERLAY} -eq 1 ]]
then
  echo "rsync -avhH --stats --progress zeus:${OUTPUTPATH}/${FILENAME} ./ && vlc ${FILENAME}"
fi

exit 0
