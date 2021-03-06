#!/bin/sh

# deletePhotoshot.sh - A script to synchronise and clean a remote device
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
# 35 */6 * * * sh /volume1/pi/deletePhotoshot.sh bristol

FOLDER=$1

ssh photoshot 'find /d00/pi/raw/ -mmin +360 -printf %P\\0' | \
    rsync -avhH --remove-source-files --stats --progress --files-from=- --from0 \
	      --rsh=ssh photoshot:/d00/pi/raw/ "/volume1/pi/${FOLDER}/raw/"