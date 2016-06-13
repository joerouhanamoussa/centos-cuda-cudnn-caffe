FROM centos:latest
ARG numCores=1
MAINTAINER Thomas Schaffter <thomas.schaffter@gmail.com>

# A Docker container with the NVIDIA drivers, CUDA Toolkit, cuDNN library and Caffe installed.
#
# @param numCores the number of CPU cores used to compile Caffe
#
# Docker build example:
#
# docker build -t centos-cuda-cudnn-caffe --build-arg numCores=24 .
#
# Docker run example:
#
# docker run -it --device /dev/nvidia0:/dev/nvidia0 --device /dev/nvidia1:/dev/nvidia1 --device /dev/nvidia2:/dev/nvidia2 --device /dev/nvidia3:/dev/nvidia3 --device /dev/nvidiactl:/dev/nvidiactl --device /dev/nvidia-uvm:/dev/nvidia-uvm centos-cuda-cudnn-caffe nvidia-smi
#
# These commands can be used to verify that CUDA and Caffe work as expected:
#
# docker run ... nvidia-smi
# docker run ... /opt/deviceQuery
# docker run ... /opt/bandwidthTest
# docker run ... /bin/bash -c "cd /opt/caffe; make runtest -j<number of cores>"
# docker run ... /bin/bash -c "cd /opt/caffe; ./examples/cifar10/train_quick.sh"

ENV CUDA_RPM http://developer.download.nvidia.com/compute/cuda/7.5/Prod/local_installers/cuda-repo-rhel7-7-5-local-7.5-18.x86_64.rpm
ENV NVIDIA_DRIVERS_RUN http://us.download.nvidia.com/XFree86/Linux-x86_64/352.79/NVIDIA-Linux-x86_64-352.79.run

RUN yum -y -q install \
  wget pciutils bzip2 vim && \
  yum -y group install "Development Tools"

RUN yum -y install epel-release dkms kernel-devel-$(uname -r) kernel-headers-$(uname -r)

# Install NVIDIA CUDA Toolkit
RUN cd /opt && \
  wget $CUDA_RPM && \
  rpm -i $(basename $CUDA_RPM) && \
  yum clean all && \
  yum -y install cuda

# Install NVIDIA drivers
RUN cd /opt && \
  wget $NVIDIA_DRIVERS_RUN && \
  chmod +x *.run && \
  ./$(basename $NVIDIA_DRIVERS_RUN) -s --no-kernel-module

ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:/usr/local/cuda-7.5/lib64

# Build CUDA samples deviceQuery and bandwidthTest
RUN cd /usr/local/cuda-7.5/samples/1_Utilities/deviceQuery && \
  make && \
  ln -s `pwd`/deviceQuery /opt/deviceQuery && \
  cd ../bandwidthTest && \
  make && \
  ln -s `pwd`/bandwidthTest /opt/bandwidthTest

# Install the NVIDIA GPU Accelerated Deep Learning library (cuDNN)
COPY cudnn-7.5-linux-x64-v5.0-rc.tgz /opt/

ENV CUDA_HOME /usr/local/cuda/

RUN cd /opt && \
  mkdir cudnn && \
  tar xvzf cudnn-7.5-linux-x64-v5.0-rc.tgz -C cudnn && \
  cp cudnn/cuda/include/cudnn.h $CUDA_HOME/include && \
  cp cudnn/cuda/lib64/libcudnn* $CUDA_HOME/lib64 && \
  chmod a+r $CUDA_HOME/lib64/libcudnn*

# Install Caffe dependencies
RUN yum -y install \
  git \
  protobuf-devel leveldb-devel snappy-devel opencv-devel boost-devel hdf5-devel \
  gflags-devel glog-devel lmdb-devel \
  openblas openblas-devel

# Compile Caffe with GPU and cuDNN support
ENV CAFFE_REPOS https://github.com/BVLC/caffe.git

RUN cd /opt && \
  git clone $CAFFE_REPOS && \
  cd caffe && \
  cp Makefile.config.example Makefile.config && \
  sed -i "/# USE_CUDNN := 1/c\USE_CUDNN := 1" Makefile.config && \
  sed -i "/BLAS := atlas/c\BLAS := open" Makefile.config && \
  sed -i "/# BLAS_INCLUDE := \/path\/to\/your\/blas/c\BLAS_INCLUDE = \/usr\/include\/openblas" Makefile.config && \
  make all -j$numCores && \
  make test -j$numCores

# Prepare the Caffe example CIFAR-10
RUN cd /opt/caffe && \
  ./data/cifar10/get_cifar10.sh && \
  ./examples/cifar10/create_cifar10.sh
  
# Cleanup
RUN rm -fr /opt/$(basename $CUDA_RPM) \
  /opt/$(basename $NVIDIA_DRIVERS_RUN) \
  /opt/cudnn-7.5-linux-x64-v5.0-rc.tgz
