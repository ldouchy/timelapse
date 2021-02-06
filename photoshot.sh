#/bin/bash

# photoshot.sh - A script to take picture on a raspberry pi
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
