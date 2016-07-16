# A Docker container with the NVIDIA drivers, CUDA Toolkit, cuDNN library and Caffe installed

### Docker build example

```bash
docker build -t centos-cuda-cudnn-caffe .
```

### Docker run examples

```bash
docker run -it --device /dev/nvidia0:/dev/nvidia0 --device /dev/nvidia1:/dev/nvidia1 --device /dev/nvidia2:/dev/nvidia2 --device /dev/nvidia3:/dev/nvidia3 --device /dev/nvidiactl:/dev/nvidiactl --device /dev/nvidia-uvm:/dev/nvidia-uvm centos-cuda-cudnn-caffe nvidia-smi
```

These commands can be used to verify that CUDA and Caffe work as expected:

```bash
docker run ... nvidia-smi
docker run ... /opt/cuda-test/deviceQuery
docker run ... /opt/cuda-test/bandwidthTest
docker run ... /bin/bash -c "cd /opt/caffe; make runtest -j<number of cores>"
docker run ... /bin/bash -c "cd /opt/caffe; ./examples/cifar10/train_quick.sh"
```
