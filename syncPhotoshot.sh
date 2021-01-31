#!/bin/sh

# associated crontab
# */10 * * * * sudo sh /volume1/pi/syncPhotoshot.sh bristol

FOLDER=$1

rsync -avHh --stats --progress photoshot:/d00/pi/raw/ /volume1/pi/${FOLDER}/raw
