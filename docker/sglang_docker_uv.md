# Guide for seperate docker image with uv

## 1. build docker on bare metal and then upload

```bash
sudo nerdctl build --progress=plain -f docker/simplified.Dockerfile --build-arg CUDA_VERSION=12.8.1 --build-arg PIP_DEFAULT_INDEX=http://nexus.sii.shaipower.online/repository/pypi/simple/ --build-arg PIP_TRUSTED_HOST=nexus.sii.shaipower.online -t sglang:cu128-base-sglang .
```

## 2. use uv to install python dependencies

> This step should run on CPU Cluster with network access.

1. Install CUDA Toolkit on CPU and Install python3-venv
```bash
# 下载 CUDA Toolkit（只安装编译工具，不需要驱动）                                                                     
wget https://developer.download.nvidia.com/compute/cuda/12.8.1/local_installers/cuda_12.8.1_570.124.06_linux.run
# 安装到用户目录（无需 sudo）
sh cuda_12.8.1_570.124.06_linux.run --toolkit --silent --installpath=$HOME/cuda-12.8.1
apt-get install python3-venv
```

2. create virtual env and install depencies with uv
```bash
chmod +x uv_install.sh
export CUDA_HOME=$HOME/cuda-12.8.1
export PATH=$CUDA_HOME/bin:$PATH
export CUDA_VERSION=12.8.1
export WORKSPACE=/sgl-workspace
export BUILD_TYPE=all
# Create a virtual environment named sglang in the directory /inspire/qb-ilm/project/daijinquan/public/env/sglang and install all packages.
./uv_install.sh --venv /inspire/qb-ilm/project/daijinquan/public/env --name sglang
```

## 3. use this virtual env with docker
```bash
# 运行同一个脚本，会自动检测并只编译缺失的组件
source /inspire/qb-ilm/project/daijinquan/public/env/sglang/bin/activate
python -c "import sglang; print(sglang.__version__)"
deactivate
```
