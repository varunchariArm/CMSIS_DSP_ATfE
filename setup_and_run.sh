#!/bin/bash

set -e  # Exit on any error

# Update and install dependencies
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y python3-pip python3.10-venv build-essential cmake

# Detect CPU architecture
ARCH=$(uname -m)
echo "Detected architecture: $ARCH"
SCRIPT_PATH="$PWD"
EXAMPLE_RESOURCES="$SCRIPT_PATH/resources_cmsis_dsp_atfe"

# Download and extract LLVM-ET (user must manually download and provide path)
if [[ "${ARCH}" == "aarch64" ]] || [[ "${ARCH}" == "arm64" ]]; then
  LLVM_TAR="LLVM-ET-Arm-20.0.0-Beta-Linux-AArch64.tar.xz"
  LLVM_DIR="LLVM-ET-Arm-20.0.0-Linux-AArch64"
elif [[ "${ARCH}" == "x86_64" ]]; then
  LLVM_TAR="LLVM-ET-Arm-20.0.0-Beta-Linux-x86_64.tar.xz"
  LLVM_DIR="LLVM-ET-Arm-20.0.0-Linux-x86_64"
else
  echo "Error: only x86-64 & aarch64/arm64 architecture is supported for now!"; exit 1;
fi

if [ ! -d "$LLVM_DIR" ]; then
    echo "Please download the LLVM toolchain ($LLVM_TAR) and place it in the current directory."
    read -p "Press enter after placing $LLVM_TAR here..."
    if [ ! -f "$LLVM_TAR" ]; then
        echo "ERROR: $LLVM_TAR not found!"
        exit 1
    fi
    tar -xvf "$LLVM_TAR"
fi

export PATH="$PWD/$LLVM_DIR/bin:$PATH"

# Download and install FVP
if [[ "${ARCH}" == "aarch64" ]] || [[ "${ARCH}" == "arm64" ]]; then
  FVP_DIR="FVP_Corstone_300_11_22"
  FVP_TAR="FVP_Corstone_SSE-300_11.22_20_Linux64_armv8l.tgz"
  if [ ! -d "$FVP_DIR" ]; then
    echo "Downloading FVP package..."
    wget https://developer.arm.com/-/media/Arm%20Developer%20Community/Downloads/OSS/FVP/Corstone-300/$FVP_TAR
    mkdir "$FVP_DIR"
    cd "$FVP_DIR"
    tar -xvf "../$FVP_TAR"
    ./FVP_Corstone_SSE-300.sh --i-agree-to-the-contained-eula --force --destination ./ --quiet --no-interactive
    cd ..
  fi
  export PATH="$PWD/$FVP_DIR/models/Linux64_armv8l_GCC-9.3/:$PATH"
  FVP_INSTALL_PATH="$PWD/$FVP_DIR/models/Linux64_armv8l_GCC-9.3/"
elif [[ "${ARCH}" == "x86_64" ]]; then
  FVP_DIR="FVP_Corstone_300_11_22"
  FVP_TAR="FVP_Corstone_SSE-300_11.22_20_Linux64.tgz"
  if [ ! -d "$FVP_DIR" ]; then
    echo "Downloading FVP package..."
    wget https://developer.arm.com/-/media/Arm%20Developer%20Community/Downloads/OSS/FVP/Corstone-300/$FVP_TAR
    mkdir "$FVP_DIR"
    cd "$FVP_DIR"
    tar -xvf "../$FVP_TAR"
    ./FVP_Corstone_SSE-300.sh --i-agree-to-the-contained-eula --force --destination ./ --quiet --no-interactive
    cd ..
  fi
  export PATH="$PWD/$FVP_DIR/models/Linux64_GCC-9.3/:$PATH"
  FVP_INSTALL_PATH="$PWD/$FVP_DIR/models/Linux64_GCC-9.3/"
else
  echo "Error: only x86-64 & aarch64/arm64 architecture is supported for now!"; exit 1;
fi


# Clone and patch Ethos-U repository
if [ ! -d "atfe" ]; then
  mkdir atfe
fi
cd atfe

if [ ! -d "ethos-u" ]; then
    git clone https://git.gitlab.arm.com/artificial-intelligence/ethos-u/ethos-u.git
fi

cd ethos-u

# Apply patches only if not already applied
if ! git apply --check $SCRIPT_PATH/diff_ethosu_cmsisdsp.patch 2>/dev/null; then
    echo "Patch diff_ethosu_cmsisdsp.patch already applied or failed check. Skipping."
else
    git apply $SCRIPT_PATH/diff_ethosu_cmsisdsp.patch
fi

python3 fetch_externals.py fetch

cd core_software
if ! git apply --check $SCRIPT_PATH/diff_core_software.patch 2>/dev/null; then
    echo "Patch diff_core_software.patch already applied or failed check. Skipping."
else
    git apply $SCRIPT_PATH/diff_core_software.patch
fi
cd cmsis-dsp
if ! git apply --check $SCRIPT_PATH/diff_cmsis_dsp_helium.patch 2>/dev/null; then
    echo "Patch diff_core_software.patch already applied or failed check. Skipping."
else
    git apply $SCRIPT_PATH/diff_cmsis_dsp_helium.patch
fi
cd ../../core_platform
if ! git apply --check $SCRIPT_PATH/diff_core_platform.patch 2>/dev/null; then
    echo "Patch diff_core_platform.patch already applied or failed check. Skipping."
else
    git apply $SCRIPT_PATH/diff_core_platform.patch
fi

# === Copying required files ===
CMSIS_DSP_DIR="applications/cmsis_dsp"
if [ ! -d "$CMSIS_DSP_DIR" ]; then
    cp -r $EXAMPLE_RESOURCES/cmsis_dsp_examples "$CMSIS_DSP_DIR"
fi

if [ ! -f "cmake/toolchain/arm-llvm-clang.cmake" ]; then
    cp $EXAMPLE_RESOURCES/arm-llvm-clang.cmake cmake/toolchain/
fi

if [ ! -f "targets/corstone-300/platform_clang.ld" ]; then
    cp $EXAMPLE_RESOURCES/platform_clang.ld targets/corstone-300/
fi

# Configure and build with CMake
TOOLCHAIN_PATH="$PWD/cmake/toolchain/arm-llvm-clang.cmake"
CMSISCORE_PATH="$PWD/../core_software/cmsis_6/CMSIS/Core"
cmake -B build targets/corstone-300 \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_PATH" \
  -DCMSISCORE="$CMSISCORE_PATH"

cmake --build build -j4

APP_BINARY="$PWD/build/applications/cmsis_dsp/cmsis_dsp.elf"

# Run the generated binary in FVP
timeout="60"

#cd ../../../FVP_Corstone_300_11_22/models/Linux64_armv8l_GCC-9.3/
cd "$FVP_INSTALL_PATH"
./FVP_Corstone_SSE-300_Ethos-U55 \
  -C mps3_board.uart0.shutdown_on_eot=1 \
  -C mps3_board.visualisation.disable-visualisation=1 \
  -C mps3_board.telnetterminal0.start_telnet=0 \
  -C mps3_board.uart0.out_file=- \
  -C mps3_board.uart0.unbuffered_output=1 \
  -a "$APP_BINARY" \
  --timelimit ${timeout} 2>&1
echo "Simulation complete"