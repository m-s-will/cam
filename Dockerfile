# This Dockerfile creates a docker image for running flecsale in containers
# at Elwetritsch TU KL.  
# The general expectation is that this container and ones layered on top of it
# will be run using Singularity with a cleaned environment and a contained
# file systems (e.g. singularity run -eC container.sif). The Singularity command
# is responsible for binding in the appropriate environment variables,
# directories, and files to make this work.

FROM ubuntu:16.04

SHELL ["/bin/bash", "-l", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update  && apt-get upgrade -y && apt-get install -y cmake \
    libgl1-mesa-dev libxt-dev qt4-default libqt4-help qt4-dev-tools \
    git build-essential libx11-dev flex curl clang python-dev \
    python3-dev  python3-numpy python-numpy libopenmpi-dev libssl-dev wget\
    binutils-gold autotools-dev automake unzip dos2unix libtbb-dev ninja-build subversion \
    nano gnupg-agent software-properties-common libnetcdf-dev libnetcdff-dev gfortran


# We do most of our work in /home/docker for the same reason. This just
# sets up the base environment in which we can build more sophisticated
# containers
RUN mkdir -p /home/docker
RUN chmod 777 /home/docker
WORKDIR /home/docker/


#install newer cmake version
#RUN cd /home; wget -qO- https://github.com/Kitware/CMake/releases/download/v3.16.5/cmake-3.16.5.tar.gz | tar xz;
#RUN cd /home/cmake-3.16.5/; ./bootstrap; make; make install;


# removes ttyname warning
RUN echo '#! /bin/sh' > /usr/bin/mesg; chmod 755 /usr/bin/mesg
ENV FC="gfortran"
ENV F77="gfortran"
ENV F90="gfortran"
ENV CC="gcc"
ENV CXX="g++"
ENV MPIF77="mpif90"
ENV MPIFC="mpif90"
ENV MPIF90="mpif90"
ENV MPICC="mpicc"



# install netcdf version 4.1.3
RUN cd /usr/local/; v=4.1.3; wget http://www.unidata.ucar.edu/downloads/netcdf/ftp/netcdf-${v}.tar.gz; tar -xf netcdf-${v}.tar.gz && cd netcdf-${v}; \
    ./configure --prefix=/usr/local --disable-dap --disable-netcdf-4 --disable-cxx --disable-shared --enable-fortran; \
    make all check; make install;

# install parallel-netcdf version 1.3.1
RUN cd /home/docker/cam; wget http://cucis.ece.northwestern.edu/projects/PnetCDF/Release/parallel-netcdf-1.6.1.tar.gz; tar -xf parallel-netcdf-1.6.1.tar.gz && cd parallel-netcdf-1.6.1; \
    ./configure --disable-cxx --prefix=/home/docker/cam/pnetcdf; make; make install;

# install PIO version 1.7.2
ENV NETCDF_PATH="/usr/local/"
ENV NETCDF="/usr/local/"
ENV PNETCDF_PATH="/home/docker/cam/pnetcdf"
ENV PNETCDF="/home/docker/cam/pnetcdf"
RUN cd /home/docker/cam; git clone https://github.com/NCAR/ParallelIO.git /home/docker/cam/pio1_7_4; cd pio1_7_4; git checkout 30b25bdb; \
    cd pio; ./configure --prefix=/home/docker/cam/pio --disable-netcdf; make; make install;
ENV PIO="/home/docker/cam/pio"
RUN echo $PNETCDF; echo $PIO; ls $PNETCDF/lib/libpnetcdf.a; ls $PIO/lib/libpio.a;
    
# needed by mesa
#RUN pip3 install mako

#install mesa
WORKDIR /usr/local
RUN wget mesa.freedesktop.org/archive/older-versions/13.x/13.0.6/mesa-13.0.6.tar.gz && tar xvzf mesa-13.0.6.tar.gz && rm mesa-13.0.6.tar.gz

WORKDIR /usr/local/mesa-13.0.6

RUN autoreconf -fi
RUN ./configure \
    --enable-osmesa\
    --disable-glx \
    --disable-driglx-direct\ 
    --disable-dri\ 
    --disable-egl \
    --with-gallium-drivers=swrast 

RUN make -j 8; make install;


# build glu
ENV C_INCLUDE_PATH '/usr/local/mesa-13.0.6/include'
ENV CPLUS_INCLUDE_PATH '/usr/local/mesa-13.0.6/include'
WORKDIR /usr/local
RUN git clone http://anongit.freedesktop.org/git/mesa/glu.git

WORKDIR /usr/local/glu
RUN ./autogen.sh --enable-osmesa
RUN ./configure --enable-osmesa
RUN make -j 8
RUN make install

#install paraview
RUN cd /home/docker; mkdir paraview; wget https://www.paraview.org/files/v5.6/ParaView-v5.6.0.tar.gz; tar -zxvf ParaView-v5.6.0.tar.gz -C paraview --strip-components 1;
# Build paraview

RUN cd /home/docker/; mkdir paraview_build; cd paraview_build; \ 
    cmake \
    -DBUILD_TESTING=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DPARAVIEW_ENABLE_CATALYST=ON  \
    -DPARAVIEW_ENABLE_PYTHON=ON \
    -DPARAVIEW_BUILD_QT_GUI=OFF \
    -DVTK_USE_X=OFF \
    -DOPENGL_INCLUDE_DIR=/usr/local/mesa-13.0.6/include \
    -DOPENGL_gl_LIBRARY=/usr/local/mesa-13.0.6/lib/libOSMesa.so \
    -DVTK_OPENGL_HAS_OSMESA=ON \
    -DOSMESA_INCLUDE_DIR=/usr/local/mesa-13.0.6/include \
    -DOSMESA_LIBRARY=/usr/local/mesa-13.0.6/lib/libOSMesa.so \
    -DPARAVIEW_USE_MPI=ON \
    ../paraview; make -j 8; make install;
    

# get the cesm data
RUN svn checkout --non-interactive --trust-server-cert --no-auth-cache --username guestuser --password friendly --depth empty https://svn-ccsm-inputdata.cgd.ucar.edu/trunk/inputdata/ /home/docker/cesm-data; 

#create the folder structure for the files we need
RUN cd /home/docker/cesm-data/; \
    svn update --non-interactive --trust-server-cert  --depth empty atm;\
    cd /home/docker/cesm-data/atm;\
    svn update --non-interactive --trust-server-cert --depth empty cam;\
    svn update --non-interactive --trust-server-cert --depth empty waccm;\
    cd /home/docker/cesm-data/atm/cam;\
    svn update --non-interactive --trust-server-cert --depth empty ocnfrac;\
    svn update --non-interactive --trust-server-cert --depth empty chem;\
    cd chem; \
    svn update --non-interactive --trust-server-cert --depth empty trop_mam;\
    svn update --non-interactive --trust-server-cert --depth empty trop_mozart;\
    cd trop_mozart;\
    svn update --non-interactive --trust-server-cert --depth empty dvel;\
    svn update --non-interactive --trust-server-cert --depth empty phot;\
    svn update --non-interactive --trust-server-cert --depth empty ub;\
    cd ..; \
    svn update --non-interactive --trust-server-cert --depth empty trop_mozart_aero;\
    cd trop_mozart_aero;\
    svn update --non-interactive --trust-server-cert --depth empty emis;\
    svn update --non-interactive --trust-server-cert --depth empty oxid;\
    cd /home/docker/cesm-data/atm/cam;\
    svn update --non-interactive --trust-server-cert --depth empty dst;\
    svn update --non-interactive --trust-server-cert --depth empty inic;\
    cd inic; \
    svn update --non-interactive --trust-server-cert --depth empty homme;\
    svn update --non-interactive --trust-server-cert --depth empty fv;\
    cd /home/docker/cesm-data/atm/cam/; \
    svn update --non-interactive --trust-server-cert --depth empty ozone;\
    svn update --non-interactive --trust-server-cert --depth empty physprops;\
    svn update --non-interactive --trust-server-cert --depth empty solar;\
    svn update --non-interactive --trust-server-cert --depth empty sst;\
    svn update --non-interactive --trust-server-cert --depth empty topo;\
    cd /home/docker/cesm-data/atm/waccm/; \
    svn update --non-interactive --trust-server-cert --depth empty phot; \
    cd /home/docker/cesm-data/; \
    svn update --non-interactive --trust-server-cert --depth empty lnd;\
    cd lnd;\
    svn update --non-interactive --trust-server-cert --depth empty clm2;\
    cd clm2; \
    svn update --non-interactive --trust-server-cert --depth empty pftdata;\
    svn update --non-interactive --trust-server-cert --depth empty snicardata;\
    svn update --non-interactive --trust-server-cert --depth empty surfdata_map;\
    svn update --non-interactive --trust-server-cert --depth empty surfdata;\
    cd /home/docker/cesm-data/; \
    svn update --non-interactive --trust-server-cert --depth empty ocn;\
    cd ocn; \
    svn update --non-interactive --trust-server-cert --depth empty docn7;\
    cd ..;\
    svn update --non-interactive --trust-server-cert --depth empty share;\
    cd share;\
    svn update --non-interactive --trust-server-cert --depth empty domains;

COPY cesm_files.txt /home/docker/cesm-data/cesm_files.txt
RUN dos2unix /home/docker/cesm-data/cesm_files.txt
# pull all the files we need
RUN cd /home/docker/cesm-data; xargs -L1 svn update --non-interactive --trust-server-cert < cesm_files.txt;

# Copy cesm and adaptor folders
COPY cesm1_2_2 /home/docker/cesm1_2_2/
COPY CamAdaptor /home/docker/cesm1_2_2/models/atm/cam/CamAdaptor

#RUN dos2unix /home/docker/cesm1_2_2/models/atm/cam/CamAdaptor/configure-cam.sh
RUN mkdir -p /home/docker/build/cam-5.3; cd /home/docker/build/cam-5.3; \
    /home/docker/cesm1_2_2/models/atm/cam/CamAdaptor/configure-cam.sh;

RUN cd /home/docker/build/cam-5.3; make -j; exit 0

RUN cd /home/docker/build/cam-5.3; mkdir CamAdaptor; cd CamAdaptor; \
    cmake \
    -DCAM_BUILD_DIR=/home/docker/build/cam-5.3 \
    -DParaView_DIR=/home/docker/paraview_build \
    /home/docker/cesm1_2_2/models/atm/cam/CamAdaptor/; make;\
    cd ..; make;



RUN mkdir -p /home/docker/run/cam-5.3; cd /home/docker/run/cam-5.3;\
    /home/docker/cesm1_2_2/models/atm/cam/CamAdaptor/build-namelist.sh;
    

COPY start_simulation.sh /home/docker/start_simulation.sh


RUN dos2unix /home/docker/start_simulation.sh
RUN chmod +x /home/docker/start_simulation.sh


#CMD ["/bin/bash"]
ENTRYPOINT ["/home/docker/paraview_build/bin/pvserver"]

