#! /bin/sh

# Configures parameters into the simulation
# should be run inside the run directory
# the run directory basename should be the same as the build directory basename
# for instance: ~/run/cam-5.3 and ~/build/cam-5.3

CAM_ROOT=/home/docker/cesm1_2_2/
camcfg=$CAM_ROOT/models/atm/cam/bld
pwd=`pwd`
DIR_NAME=`basename $pwd`
CAM_BUILD=/home/docker/build/$DIR_NAME
CSMDATA=/home/docker/cesm-data;export CSMDATA

# Run the sim for 7 days, average every 24 hours, timestep every 30 minutes
$camcfg/build-namelist -test -config $CAM_BUILD/config_cache.xml -namelist "&seq_timemgr_inparm stop_n=7 stop_option='ndays' / &cam_inparm nhtfrq=-24, -24, -24, -24, -24, -24 hfilename_spec='%c.cam.h%t.%y-%m-%d-%s.nc' print_step_cost=.true. / "

# Run the sim for 3 months, average every week
#$camcfg/build-namelist -test -config $CAM_BUILD/config_cache.xml -namelist "&seq_timemgr_inparm stop_n=3 stop_option='nmonths' / &cam_inparm  nhtfrq=336, -24, -24, -24, -24, -24 mfilt=10,30,30,30,30,30 hfilename_spec='%c.cam.h%t.%y-%m-%d-%s.nc' print_step_cost=.true. / "
