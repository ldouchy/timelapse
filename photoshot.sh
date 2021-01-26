#/bin/bash

# associated crontab
# * * * * * ~/photoshot.sh raw > /dev/null 2>&1


FOLDERNAME=$1
DIR=/d00/pi/${FOLDERNAME}

mkdir -p ${DIR}

picture () {
    DATE=$1

    raspistill \
      --nopreview \
      --quality 100 \
      -o ~/${DATE}.jpeg

    mv ~/${DATE}.jpeg ${DIR}/${DATE}.jpeg
    chown ldouchy:users ${DIR}/${DATE}.jpeg
    chmod 664 ${DIR}/${DATE}.jpeg
}


picture $(date +%Y%m%dT%H%M%S%z) &

sleep 30

picture $(date +%Y%m%dT%H%M%S%z) &
