# A Docker container with the NVIDIA drivers, CUDA Toolkit, cuDNN library and Caffe installed.

### Docker build arguments

@param numCores the number of CPU cores used to compile Caffe

### Docker build example

```bash
docker build -t centos-cuda-cudnn-caffe --build-arg numCores=24 .
```

### Docker run example

```bash
docker run -it --device /dev/nvidia0:/dev/nvidia0 --device /dev/nvidia1:/dev/nvidia1 --device /dev/nvidia2:/dev/nvidia2 --device /dev/nvidia3:/dev/nvidia3 --device /dev/nvidiactl:/dev/nvidiactl --device /dev/nvidia-uvm:/dev/nvidia-uvm centos-cuda-cudnn-caffe nvidia-smi
```

The following commands can be used to verify that CUDA and Caffe work as expected:

```bash
docker run ... nvidia-smi
docker run ... /opt/deviceQuery
docker run ... /opt/bandwidthTest
docker run ... /bin/bash -c "cd /opt/caffe; make runtest -j<number of cores>"
docker run ... /bin/bash -c "cd /opt/caffe; ./examples/cifar10/train_quick.sh"
```bash
