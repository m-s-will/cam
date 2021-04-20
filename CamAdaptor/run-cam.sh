#! /bin/sh
cd /home/docker/run/cam-5.3/

# run cam5 on one processor
#LD_LIBRARY_PATH=/home/docker/build/cam-5.3/CamAdaptor /home/docker/build/cam-5.3/cam | tee cam.log

# runs the cam5 simulation on xx MPI processors. 
# WARNING
# Make sure the value for -np matches the value for -ntasks in configure-cam.sh
#pwd=`pwd`
#DIR_NAME=`basename $pwd`
#CAM_BUILD=/home/docker/build/cam-5.3
LD_LIBRARY_PATH=/home/docker/build/cam-5.3/CamAdaptor mpiexec --allow-run-as-root -np 4 /home/docker/build/cam-5.3/cam | tee cam.log
#LD_LIBRARY_PATH=${CAM_BUILD}/CamAdaptor mpiexec -np 2 xterm -e gdb -x ~/src/cesm1_2_2/.gdbinit --args ${CAM_BUILD}/cam
