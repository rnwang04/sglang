# Guide for seperate docker image with python venv

> below guide is based on python 3.12

## 1. use venv to install python dependencies

> Step1 should run on CPU Cluster with network access.

1. Install python3.12
```bash
add-apt-repository ppa:deadsnakes/ppa
apt update
apt install python3.12 python3.12-venv python3.12-dev
```

2. Install CUDA Toolkit
```bash                                                                    
wget https://developer.download.nvidia.com/compute/cuda/12.8.1/local_installers/cuda_12.8.1_570.124.06_linux.run
sh cuda_12.8.1_570.124.06_linux.run --toolkit --silent --installpath=$HOME/cuda-12.8.1
```

3. create virtual env and install depencies with uv
```bash
chmod +x uv_install.sh
export CUDA_HOME=$HOME/cuda-12.8.1
export PATH=$CUDA_HOME/bin:$PATH
export CUDA_VERSION=12.8.1
export WORKSPACE=/sgl-workspace
export BUILD_TYPE=all
export SYSTEM_PYTHON=/usr/bin/python3.12
# Create a virtual environment named sglang in the directory /inspire/qb-ilm/project/daijinquan/public/env/sglang-py312 and install all packages.
rm -rf /sgl-workspace
./uv_install.sh --venv /inspire/qb-ilm/project/daijinquan/public/env --name sglang-py312
```

## 2. build docker on bare metal and then upload

```bash
sudo nerdctl build --progress=plain -f docker/simplified.Dockerfile --build-arg CUDA_VERSION=12.8.1 --build-arg PIP_DEFAULT_INDEX=http://nexus.sii.shaipower.online/repository/pypi/simple/ --build-arg PIP_TRUSTED_HOST=nexus.sii.shaipower.online --build-arg PYTHON_VERSION=3.12.12 -t sglang:cu128-base-sglang-py312 .
```

## 3. use this virtual env with docker
```bash
source /inspire/qb-ilm/project/daijinquan/public/env/sglang-py312/bin/activate
python -c "import sglang; print(sglang.__version__)"
deactivate
```
