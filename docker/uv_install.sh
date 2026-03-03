#!/bin/bash
# uv_install.sh - Install SGLang and dependencies using uv
#
# Usage:
#   ./uv_install.sh --venv /path/to/venvs --name sglang
#
# This script:
#   1. Creates a virtual environment using system Python (3.10)
#   2. Installs uv in the virtual environment
#   3. Uses uv to install all packages
#
# Environment variables:
#   CUDA_VERSION          - CUDA version (default: 12.8.1)
#   BUILD_TYPE            - SGLang build type: all, srt, openai (default: all)
#   SGL_KERNEL_VERSION    - sgl-kernel version (default: 0.3.21)
#   FLASHINFER_VERSION    - FlashInfer version (default: 0.6.3)
#   WORKSPACE             - Workspace directory (default: /sgl-workspace)
#   SYSTEM_PYTHON         - System Python path (default: /usr/bin/python3.10)
#   SKIP_DEEPEP           - Skip DeepEP: 0 or 1 (default: 0)
#   SKIP_MOONCAKE         - Skip Mooncake: 0 or 1 (default: 0)
#   SKIP_GATEWAY          - Skip sgl-model-gateway: 0 or 1 (default: 0)
#   UPGRADE_TRANSFORMERS  - Upgrade transformers: true or false (default: true)

set -e

# ============================================
# Parse command line arguments
# ============================================
VENV_DIR=""
VENV_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --venv)
            VENV_DIR="$2"
            shift 2
            ;;
        --name)
            VENV_NAME="$2"
            shift 2
            ;;
        --python)
            SYSTEM_PYTHON="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 --venv DIR --name NAME [options]"
            echo ""
            echo "Options:"
            echo "  --venv DIR     Parent directory for virtual environment"
            echo "  --name NAME    Name of the virtual environment"
            echo "  --python PATH  System Python path (default: /usr/bin/python3.10)"
            echo "  --help         Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --venv /opt/venvs --name sglang"
            echo "  # Creates: /opt/venvs/sglang"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate arguments
if [ -z "$VENV_DIR" ] || [ -z "$VENV_NAME" ]; then
    echo "ERROR: --venv and --name are required"
    echo "Run '$0 --help' for usage"
    exit 1
fi

# ============================================
# Default values
# ============================================
CUDA_VERSION="${CUDA_VERSION:-12.8.1}"
BUILD_TYPE="${BUILD_TYPE:-all}"
SGL_KERNEL_VERSION="${SGL_KERNEL_VERSION:-0.3.21}"
FLASHINFER_VERSION="${FLASHINFER_VERSION:-0.6.3}"
WORKSPACE="${WORKSPACE:-/sgl-workspace}"
SYSTEM_PYTHON="${SYSTEM_PYTHON:-/usr/bin/python3.10}"
SKIP_DEEPEP="${SKIP_DEEPEP:-0}"
SKIP_MOONCAKE="${SKIP_MOONCAKE:-0}"
SKIP_GATEWAY="${SKIP_GATEWAY:-0}"
UPGRADE_TRANSFORMERS="${UPGRADE_TRANSFORMERS:-true}"
BUILD_AND_DOWNLOAD_PARALLEL="${BUILD_AND_DOWNLOAD_PARALLEL:-8}"
GITHUB_ARTIFACTORY="${GITHUB_ARTIFACTORY:-github.com}"
DEEPEP_COMMIT="${DEEPEP_COMMIT:-9af0e0d0e74f3577af1979c9b9e1ac2cad0104ee}"
MOONCAKE_VERSION="${MOONCAKE_VERSION:-0.3.9}"
MOONCAKE_COMPILE_ARG="${MOONCAKE_COMPILE_ARG:--DUSE_HTTP=ON -DUSE_MNNVL=ON -DUSE_CUDA=ON -DWITH_EP=ON}"

VENV_PATH="${VENV_DIR}/${VENV_NAME}"

# Determine CUDA index
case "$CUDA_VERSION" in
    12.6.1) CUINDEX=126 ;;
    12.8.1) CUINDEX=128 ;;
    12.9.1) CUINDEX=129 ;;
    13.0.1) CUINDEX=130 ;;
    *) echo "Unsupported CUDA version: $CUDA_VERSION" && exit 1 ;;
esac

CUDA_MAJOR="${CUDA_VERSION%%.*}"

echo "=============================================="
echo "SGLang Installation"
echo "=============================================="
echo "VENV_PATH: ${VENV_PATH}"
echo "SYSTEM_PYTHON: ${SYSTEM_PYTHON}"
echo "CUDA_VERSION: ${CUDA_VERSION}"
echo "WORKSPACE: ${WORKSPACE}"
echo "=============================================="

# ============================================
# Step 0: Create virtual environment
# ============================================
echo ""
echo "=== [0/8] Creating virtual environment ==="

# Verify system Python exists
if [ ! -x "$SYSTEM_PYTHON" ]; then
    echo "ERROR: System Python not found at ${SYSTEM_PYTHON}"
    exit 1
fi

echo "System Python: ${SYSTEM_PYTHON}"
echo "Version: $(${SYSTEM_PYTHON} --version)"

mkdir -p "${VENV_DIR}"

# Create virtual environment if not exists
if [ -d "${VENV_PATH}" ]; then
    echo "Virtual environment already exists at ${VENV_PATH}"
    read -p "Do you want to recreate it? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "${VENV_PATH}"
        "${SYSTEM_PYTHON}" -m venv "${VENV_PATH}" || \
        "${SYSTEM_PYTHON}" -m virtualenv "${VENV_PATH}"
    fi
else
    "${SYSTEM_PYTHON}" -m venv "${VENV_PATH}" || \
    "${SYSTEM_PYTHON}" -m virtualenv "${VENV_PATH}"
fi

# Activate virtual environment
source "${VENV_PATH}/bin/activate"
hash -r

echo "Activated: ${VENV_PATH}"
echo "Python: $(which python)"
echo "Version: $(python --version)"

# Install pip and uv in venv
echo ""
echo "=== Installing pip and uv in venv ==="
python -m pip install --upgrade pip
pip install uv

echo "uv version: $(uv --version)"

# ============================================
# Step 1: Install base packages
# ============================================
echo ""
echo "=== [1/8] Installing base packages ==="
uv pip install pip setuptools wheel html5lib six

# ============================================
# Step 2: Install sgl-kernel
# ============================================
echo ""
echo "=== [2/8] Installing sgl-kernel ==="
if [ "$CUDA_VERSION" = "12.6.1" ]; then
    uv pip install \
        "https://${GITHUB_ARTIFACTORY}/sgl-project/whl/releases/download/v${SGL_KERNEL_VERSION}/sgl_kernel-${SGL_KERNEL_VERSION}+cu124-cp310-abi3-manylinux2014_$(uname -m).whl" \
        --reinstall --no-deps
elif [ "$CUDA_VERSION" = "12.8.1" ] || [ "$CUDA_VERSION" = "12.9.1" ]; then
    uv pip install "sgl-kernel==${SGL_KERNEL_VERSION}"
elif [ "$CUDA_VERSION" = "13.0.1" ]; then
    uv pip install \
        "https://github.com/sgl-project/whl/releases/download/v${SGL_KERNEL_VERSION}/sgl_kernel-${SGL_KERNEL_VERSION}+cu130-cp310-abi3-manylinux2014_$(uname -m).whl" \
        --reinstall --no-deps
fi

# ============================================
# Step 3: Clone and install SGLang
# ============================================
echo ""
echo "=== [3/8] Installing SGLang ==="

mkdir -p "${WORKSPACE}"

if [ ! -d "${WORKSPACE}/sglang" ]; then
    echo "Cloning SGLang..."
    git clone --depth=1 https://github.com/sgl-project/sglang.git "${WORKSPACE}/sglang"
else
    echo "SGLang directory already exists, skipping clone"
fi

cd "${WORKSPACE}/sglang"
# Install sglang (non-editable mode for portability)
uv pip install "./python[${BUILD_TYPE}]" \
    --extra-index-url "https://download.pytorch.org/whl/cu${CUINDEX}" \
    --extra-index-url "https://flashinfer.ai/whl/cu${CUINDEX}/torch2.6" \
    --index-strategy unsafe-best-match

# Download flashinfer cubin
echo "Downloading flashinfer cubin..."
FLASHINFER_CUBIN_DOWNLOAD_THREADS=${BUILD_AND_DOWNLOAD_PARALLEL} FLASHINFER_LOGGING_LEVEL=warning python -m flashinfer --download-cubin || true

# ============================================
# Step 4: Install DeepEP
# ============================================
if [ "$SKIP_DEEPEP" != "1" ]; then
    echo ""
    echo "=== [4/8] Installing DeepEP ==="

    cd "${WORKSPACE}"

    if [ ! -d "${WORKSPACE}/DeepEP" ]; then
        curl --retry 3 --retry-delay 2 -fsSL -o ${DEEPEP_COMMIT}.zip \
            "https://${GITHUB_ARTIFACTORY}/deepseek-ai/DeepEP/archive/${DEEPEP_COMMIT}.zip"
        unzip -q ${DEEPEP_COMMIT}.zip && rm ${DEEPEP_COMMIT}.zip
        mv DeepEP-${DEEPEP_COMMIT} DeepEP
        cd DeepEP

        # Patch timeout values
        sed -i 's/#define NUM_CPU_TIMEOUT_SECS 100/#define NUM_CPU_TIMEOUT_SECS 1000/' csrc/kernels/configs.cuh
        sed -i 's/#define NUM_TIMEOUT_CYCLES 200000000000ull/#define NUM_TIMEOUT_CYCLES 2000000000000ull/' csrc/kernels/configs.cuh
    else
        echo "DeepEP directory already exists, skipping clone"
        cd "${WORKSPACE}/DeepEP"
    fi

    # Determine CUDA arch list
    case "$CUDA_VERSION" in
        12.6.1) CHOSEN_TORCH_CUDA_ARCH_LIST='9.0' ;;
        12.8.1) CHOSEN_TORCH_CUDA_ARCH_LIST='9.0;10.0' ;;
        12.9.1|13.0.1) CHOSEN_TORCH_CUDA_ARCH_LIST='9.0;10.0;10.3' ;;
    esac

    # CUDA 13 specific patch
    if [ "$CUDA_MAJOR" = "13" ]; then
        sed -i "/^    include_dirs = \['csrc\/'\]/a\    include_dirs.append('${CUDA_HOME}/include/cccl')" setup.py 2>/dev/null || true
    fi

    TORCH_CUDA_ARCH_LIST="${CHOSEN_TORCH_CUDA_ARCH_LIST}" MAX_JOBS=${BUILD_AND_DOWNLOAD_PARALLEL} pip install --no-build-isolation .
else
    echo ""
    echo "=== [4/8] Skipping DeepEP (SKIP_DEEPEP=1) ==="
fi

# ============================================
# Step 5: Install Mooncake
# ============================================
if [ "$SKIP_MOONCAKE" != "1" ]; then
    echo ""
    echo "=== [5/8] Installing Mooncake ==="

    cd "${WORKSPACE}"

    if [ "$CUDA_MAJOR" -ge 13 ]; then
        echo "CUDA >= 13, building mooncake-transfer-engine from source..."
        if [ ! -d "${WORKSPACE}/Mooncake" ]; then
            git clone --branch "v${MOONCAKE_VERSION}" --depth 1 https://github.com/kvcache-ai/Mooncake.git
        fi
        cd Mooncake
        bash dependencies.sh
        mkdir -p build && cd build
        cmake .. ${MOONCAKE_COMPILE_ARG}
        make -j$(nproc)
        make install
    else
        echo "CUDA < 13, installing mooncake-transfer-engine via uv..."
        uv pip install "mooncake-transfer-engine==${MOONCAKE_VERSION}"
    fi
else
    echo ""
    echo "=== [5/8] Skipping Mooncake (SKIP_MOONCAKE=1) ==="
fi

# ============================================
# Step 6: Install sgl-model-gateway
# ============================================
if [ "$SKIP_GATEWAY" != "1" ] && [ -d "${WORKSPACE}/sglang/sgl-model-gateway" ]; then
    echo ""
    echo "=== [6/8] Building sgl-model-gateway ==="

    # Install protoc if not available
    if ! command -v protoc &> /dev/null; then
        echo "Installing protoc..."
        PROTOC_VERSION="${PROTOC_VERSION:-25.1}"
        ARCH=$(uname -m)
        if [ "$ARCH" = "x86_64" ]; then
            PROTOC_ARCH="linux-x86_64"
        elif [ "$ARCH" = "aarch64" ]; then
            PROTOC_ARCH="linux-aarch_64"
        fi

        curl --retry 3 --retry-delay 2 -fsSL -o /tmp/protoc.zip \
            "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-${PROTOC_ARCH}.zip"

        mkdir -p ~/.local/bin ~/.local/include
        unzip -o /tmp/protoc.zip -d ~/.local
        rm /tmp/protoc.zip
        export PATH="$HOME/.local/bin:$PATH"
        echo "protoc installed: $(protoc --version)"
    fi

    # Install Rust if not available
    if ! command -v cargo &> /dev/null; then
        echo "Installing Rust..."
        curl --proto '=https' --tlsv1.2 --retry 3 --retry-delay 2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi

    uv pip install maturin

    cd "${WORKSPACE}/sglang/sgl-model-gateway/bindings/python"
    ulimit -n 65536 2>/dev/null || true
    maturin build --release --features vendored-openssl --out dist
    pip install --force-reinstall dist/*.whl

    cd "${WORKSPACE}/sglang/sgl-model-gateway"
    cargo build --release --bin sgl-model-gateway --features vendored-openssl

    # Install binary
    cp target/release/sgl-model-gateway "${VENV_PATH}/bin/sgl-model-gateway"

    # Cleanup
    rm -rf target dist
else
    echo ""
    echo "=== [6/8] Skipping sgl-model-gateway (SKIP_GATEWAY=1) ==="
fi

# ============================================
# Step 7: Install additional packages
# ============================================
echo ""
echo "=== [7/8] Installing additional packages ==="

uv pip install \
    datamodel_code_generator \
    pre-commit \
    pytest \
    black \
    isort \
    icdiff \
    wheel \
    scikit-build-core \
    nixl \
    py-spy \
    cubloaty \
    google-cloud-storage \
    pandas \
    matplotlib \
    tabulate \
    termplotlib

# ============================================
# Step 8: Patches and final setup
# ============================================
echo ""
echo "=== [8/8] Applying patches ==="

# NVIDIA packages patch
echo "Patching NVIDIA packages..."
if [ "$CUDA_MAJOR" = "12" ]; then
    uv pip install nvidia-nccl-cu12==2.28.3 --reinstall --no-deps
    uv pip install nvidia-cudnn-cu12==9.16.0.29 --reinstall --no-deps
elif [ "$CUDA_MAJOR" = "13" ]; then
    uv pip install nvidia-nccl-cu13==2.28.3 --reinstall --no-deps
    uv pip install nvidia-cudnn-cu13==9.16.0.29 --reinstall --no-deps
    uv pip install nvidia-cublas==13.1.0.3 --reinstall --no-deps
    uv pip install nixl-cu13 --no-deps
    uv pip install cuda-python==13.1.1
fi

# Upgrade urllib3
uv pip install --upgrade "urllib3>=2.6.3"

# Upgrade transformers
if [ "$UPGRADE_TRANSFORMERS" = "true" ]; then
    echo "Upgrading transformers..."
    uv pip install --upgrade "transformers==5.2.0"
fi

echo ""
echo "=============================================="
echo "Installation complete!"
echo "=============================================="
echo ""
echo "Virtual environment: ${VENV_PATH}"
echo "Workspace: ${WORKSPACE}"
echo ""
echo "To use on GPU node:"
echo "  1. Transfer ${VENV_PATH} and ${WORKSPACE} to GPU node"
echo "  2. source ${VENV_PATH}/bin/activate"
echo "  3. python -m sglang.launch_server ..."
echo "=============================================="
