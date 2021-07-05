#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(pwd)
CLEAN_SOURCE=false
CLEAN_BUILD=false
INSTALL_LLVM=false

COMMAND_LINE_TOOLS_DIR=/Library/Developer/CommandLineTools
CLT_USR_INCLUDE=${COMMAND_LINE_TOOLS_DIR}/SDKs/MacOSX.sdk/usr/include
CLT_USR_LIB=${COMMAND_LINE_TOOLS_DIR}/SDKs/MacOSX.sdk/usr/lib

VERSION=11.1.0
BASE_DIR=/opt/llvm
INSTALL_DIR=${BASE_DIR}/${VERSION}
BASE_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-${VERSION}"
PACKAGES=(llvm clang clang-tools-extra libcxx libcxxabi libunwind lld lldb)
HOST_ARCHS=(x86_64 arm64)
TARGET_ARCHS=(X86 ARM AArch64)
CMAKE_OSX_SYSROOT=$(xcrun --sdk macosx --show-sdk-path)

function join {
    local INPUT_ARRAY
    read -r -a INPUT_ARRAY <<< "$1"
    local DELIMITER=$2
    if [ -z "${DELIMITER}" ]; then
        DELIMITER=";"
    fi
    local JOINED=$(printf "${DELIMITER}%s" "${INPUT_ARRAY[@]}")
    echo "${JOINED:1}"
}

if [ ${INSTALL_LLVM} = true ]; then
    echo "Create install directory - ${INSTALL_DIR}"
    sudo mkdir -p ${INSTALL_DIR}
    sudo chown -R ${USER}:staff ${BASE_DIR}
fi

brew install swig cmake ninja

if [ ${CLEAN_SOURCE} = true ]; then
    rm -rf source
fi
mkdir -p source
mkdir -p dloads

for PACKAGE in "${PACKAGES[@]}"; do
    PACKAGE_XZ=${PACKAGE}-${VERSION}.src.tar.xz
    rm -f ${PACKAGE_XZ}
    echo "Download - ${PACKAGE}"
    curl -L ${BASE_URL}/${PACKAGE_XZ} --output dloads/${PACKAGE_XZ} --progress-bar
    DESTINATION_PATH=source/${PACKAGE}
    mkdir -p ${DESTINATION_PATH}
    tar --strip-components=1 -C ${DESTINATION_PATH} -xf dloads/${PACKAGE_XZ}
done

if [ ${CLEAN_BUILD} = true ]; then
    rm -rf build
fi
mkdir -p build
pushd build

cmake \
    -D CMAKE_BUILD_TYPE=Debug \
    -D CMAKE_OSX_ARCHITECTURES="$(join "${HOST_ARCHS[*]}")" \
    -D CMAKE_VERBOSE_MAKEFILE=ON \
    -D CMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
    -D CMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT} \
    -D CMAKE_IGNORE_PATH="${CLT_USR_INCLUDE};${CLT_USR_LIB}" \
    -D LLVM_INCLUDE_EXAMPLES=OFF \
    -D LLVM_INCLUDE_TESTS=OFF \
    -D LLVM_ENABLE_EH=ON \
    -D LLVM_ENABLE_IDE=ON \
    -D LLVM_ENABLE_FFI=ON \
    -D LLVM_ENABLE_RTTI=ON \
    -D LLVM_BUILD_DOCS=OFF \
    -D LLVM_ENABLE_DOXYGEN=OFF \
    -D LLVM_INSTALL_UTILS=ON \
    -D LLVM_BUILD_EXAMPLES=ON \
    -D LLVM_BUILD_TOOLS=ON \
    -D LLVM_BUILD_TESTS=OFF \
    -D LLVM_BUILD_LLVM_DYLIB=ON \
    -D LLVM_BUILD_LLVM_C_DYLIB=ON \
    -D LLVM_OPTIMIZED_TABLEGEN=ON \
    -D LLVM_ENABLE_LIBCXX=ON \
    -D LLVM_BUILD_EXTERNAL_COMPILER_RT=ON \
    -D LLVM_CREATE_XCODE_TOOLCHAIN=ON \
    -D LLVM_LINK_LLVM_DYLIB=ON \
    -D LLVM_ENABLE_PROJECTS="$(join "${PACKAGES[*]}")" \
    -D LLVM_TARGETS_TO_BUILD="$(join "${TARGET_ARCHS[*]}")" \
    -D LLDB_USE_SYSTEM_DEBUGSERVER=ON \
    -D LLDB_ENABLE_PYTHON=OFF \
    -D LLDB_ENABLE_LUA=OFF \
    -D LLDB_INCLUDE_TESTS=OFF \
    -W no-dev \
    -G Ninja \
    ../source/llvm
cmake --build .
if [ ${INSTALL_LLVM} = true ]; then
    cmake --build . --target install
    cmake --build . --target install-xcode-toolchain
fi

popd

