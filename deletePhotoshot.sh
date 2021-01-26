#!/bin/sh

# associated crontab
# 35 */6 * * * sh /volume1/pi/deletePhotoshot.sh bristol

FOLDER=$1

ssh photoshot 'find /d00/pi/raw/ -mmin +360 -printf %P\\0' | \
    rsync -avhH --remove-source-files --stats --progress --files-from=- --from0 \
	      --rsh=ssh photoshot:/d00/pi/raw/ "/volume1/pi/${FOLDER}/raw/"