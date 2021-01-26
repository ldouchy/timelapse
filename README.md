# timelapse
Collection of scripts to take pictures, add timestamp to them and build a video

# Hardware components
## Camera
Pictures are taken via a raspberry pi zero W with an official camera v2.1. To protect the raspberry and it's camera, the official case with the camera lid as well as a fair amount of duck tape suffice.

## NAS
Data are store on a NAS an old DS412+ 

## Workstation
A computer running linux with the dependencies installed. The timestamp creation is surprisingly resource consuming fortunately can be parallelise easily. Many cores will help for that step. On the contrary the video creation require few fast cores, unless you manage to install some hardware acceleration.
  



# Software pieces
## Camera
Script `photshot.sh` with it's associated crontab running every minute

## NAS
2 scripts:
* `syncPhotoshot.sh` to synchronise every 10 minutes pictures available on the camera and the NAS
* `deletePhotoshot.sh` to delete pictures older than a day on the camera

## Workstation
`buildTimelapse.sh` to arrange the pictures per date (1 folder per day), create the tagged version of each picture and combine them to make a video


# To do
Create a cron job to stop running `buildTimelapse.sh` manually