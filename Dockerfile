FROM centos:latest
MAINTAINER Thomas Schaffter <thomas.schaffter@gmail.com>

# A Docker container with the NVIDIA drivers, CUDA Toolkit, cuDNN library and Caffe installed.
# The end of this script contains specific instructions for the Digital Mammography DREAM Challenge.

ENV CUDA_RPM http://developer.download.nvidia.com/compute/cuda/7.5/Prod/local_installers/cuda-repo-rhel7-7-5-local-7.5-18.x86_64.rpm
#ENV NVIDIA_DRIVERS_RUN http://us.download.nvidia.com/XFree86/Linux-x86_64/352.79/NVIDIA-Linux-x86_64-352.79.run
ENV NVIDIA_DRIVERS_RUN http://us.download.nvidia.com/XFree86/Linux-x86_64/352.63/NVIDIA-Linux-x86_64-352.63.run

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
  mkdir -p /opt/cuda-test && \
  ln -s `pwd`/deviceQuery /opt/cuda-test/deviceQuery && \
  cd ../bandwidthTest && \
  make && \
  ln -s `pwd`/bandwidthTest /opt/cuda-test/bandwidthTest

# Install NVIDIA GPU Accelerated Deep Learning library (cuDNN)
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
  openblas openblas-devel \
  python-devel python-pip freetype-devel libpng-devel

RUN pip install --upgrade pip

# Compile Caffe with GPU and cuDNN support
ENV CAFFE_REPOS https://github.com/BVLC/caffe.git
ENV CAFFE_ROOT /opt/caffe
ENV CAFFE_BRANCH master

RUN mkdir -p $CAFFE_ROOT && \
  git clone -b $CAFFE_BRANCH $CAFFE_REPOS $CAFFE_ROOT

# Configure Caffe
RUN cd $CAFFE_ROOT && \
  cp Makefile.config.example Makefile.config && \
  sed -i "/# USE_CUDNN := 1/c\USE_CUDNN := 1" Makefile.config && \
  sed -i "/BLAS := atlas/c\BLAS := open" Makefile.config && \
  sed -i "/# BLAS_INCLUDE := \/path\/to\/your\/blas/c\BLAS_INCLUDE := \/usr\/include\/openblas" Makefile.config && \
  sed -i "/PYTHON_INCLUDE :=/a\\/usr\/lib64\/python2.7\/site-packages\/numpy\/core\/include \\\\" Makefile.config

# Compile and test
RUN cd $CAFFE_ROOT && \
  make all -j$(($(nproc)-1)) && \
  make test -j$(($(nproc)-1))

# Compile the Caffe Python module
RUN cd $CAFFE_ROOT/python && \
  for req in $(cat requirements.txt); do pip install $req; done && \
  cd .. && \
  make pycaffe -j$(($(nproc)-1))

ENV PYCAFFE_ROOT $CAFFE_ROOT/python
ENV PYTHONPATH $PYCAFFE_ROOT:$PYTHONPATH
ENV PATH $CAFFE_ROOT/build/tools:$PYCAFFE_ROOT:$PATH
RUN echo "$CAFFE_ROOT/build/lib" >> /etc/ld.so.conf.d/caffe.conf && ldconfig

# Prepare the Caffe example CIFAR-10
#RUN cd /opt/caffe && \
#  ./data/cifar10/get_cifar10.sh && \
#  ./examples/cifar10/create_cifar10.sh

# Cleanup
RUN rm -fr /opt/$(basename $CUDA_RPM) \
  /opt/$(basename $NVIDIA_DRIVERS_RUN) \
  /opt/cudnn-7.5-linux-x64-v5.0-rc.tgz

# Prepare for the Digital Mammography DREAM Challenge
RUN pip install pydicom

WORKDIR /
COPY train.sh .
COPY test.sh .
