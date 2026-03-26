#!/bin/bash

# =============================================================================
# libssh2 XCFramework 构建脚本
# 为 ShellMate macOS 应用构建 libssh2 静态库
#
# 依赖：Xcode Command Line Tools, curl, tar
# 输出：Frameworks/libssh2.xcframework
# =============================================================================

set -e

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
FRAMEWORKS_DIR="$PROJECT_ROOT/Frameworks"

# 版本
OPENSSL_VERSION="3.2.1"
LIBSSH2_VERSION="1.11.0"

# 下载 URL
OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
LIBSSH2_URL="https://github.com/libssh2/libssh2/releases/download/libssh2-${LIBSSH2_VERSION}/libssh2-${LIBSSH2_VERSION}.tar.gz"

# macOS 部署目标
MACOS_DEPLOYMENT_TARGET="13.0"

# 架构
ARCHS=("arm64" "x86_64")

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 清理构建目录
clean() {
    log_info "清理构建目录..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
}

# 下载源码
download_sources() {
    log_info "下载源码..."

    cd "$BUILD_DIR"

    # 下载 OpenSSL
    if [ ! -f "openssl-${OPENSSL_VERSION}.tar.gz" ]; then
        log_info "下载 OpenSSL ${OPENSSL_VERSION}..."
        curl -L -o "openssl-${OPENSSL_VERSION}.tar.gz" "$OPENSSL_URL"
    fi

    # 下载 libssh2
    if [ ! -f "libssh2-${LIBSSH2_VERSION}.tar.gz" ]; then
        log_info "下载 libssh2 ${LIBSSH2_VERSION}..."
        curl -L -o "libssh2-${LIBSSH2_VERSION}.tar.gz" "$LIBSSH2_URL"
    fi

    # 解压
    log_info "解压源码..."
    tar -xzf "openssl-${OPENSSL_VERSION}.tar.gz"
    tar -xzf "libssh2-${LIBSSH2_VERSION}.tar.gz"
}

# 构建 OpenSSL
build_openssl() {
    local ARCH=$1
    local INSTALL_DIR="$BUILD_DIR/openssl-install-${ARCH}"

    log_info "构建 OpenSSL for ${ARCH}..."

    # 清理环境变量，避免之前的设置影响
    unset CFLAGS
    unset LDFLAGS
    unset PKG_CONFIG_PATH

    cd "$BUILD_DIR/openssl-${OPENSSL_VERSION}"

    # 清理之前的构建
    make clean 2>/dev/null || true
    make distclean 2>/dev/null || true

    # 配置
    if [ "$ARCH" == "arm64" ]; then
        ./Configure darwin64-arm64-cc \
            --prefix="$INSTALL_DIR" \
            -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET \
            no-shared \
            no-tests \
            no-docs
    else
        ./Configure darwin64-x86_64-cc \
            --prefix="$INSTALL_DIR" \
            -mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET \
            no-shared \
            no-tests \
            no-docs
    fi

    # 编译
    make -j$(sysctl -n hw.ncpu)
    make install_sw

    log_info "OpenSSL ${ARCH} 构建完成"
}

# 构建 libssh2
build_libssh2() {
    local ARCH=$1
    local OPENSSL_DIR="$BUILD_DIR/openssl-install-${ARCH}"
    local INSTALL_DIR="$BUILD_DIR/libssh2-install-${ARCH}"

    log_info "构建 libssh2 for ${ARCH}..."

    cd "$BUILD_DIR/libssh2-${LIBSSH2_VERSION}"

    # 清理
    rm -rf build-${ARCH}
    mkdir -p build-${ARCH}
    cd build-${ARCH}

    # 设置编译器标志
    export CFLAGS="-arch ${ARCH} -mmacosx-version-min=${MACOS_DEPLOYMENT_TARGET} -I${OPENSSL_DIR}/include"
    export LDFLAGS="-arch ${ARCH} -L${OPENSSL_DIR}/lib"
    export PKG_CONFIG_PATH="${OPENSSL_DIR}/lib/pkgconfig"

    # 配置 (使用 cmake)
    cmake .. \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
        -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET}" \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DOPENSSL_ROOT_DIR="${OPENSSL_DIR}" \
        -DOPENSSL_INCLUDE_DIR="${OPENSSL_DIR}/include" \
        -DOPENSSL_CRYPTO_LIBRARY="${OPENSSL_DIR}/lib/libcrypto.a" \
        -DOPENSSL_SSL_LIBRARY="${OPENSSL_DIR}/lib/libssl.a" \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_TESTING=OFF \
        -DENABLE_ZLIB_COMPRESSION=ON \
        -DCRYPTO_BACKEND=OpenSSL

    # 编译
    make -j$(sysctl -n hw.ncpu)
    make install

    log_info "libssh2 ${ARCH} 构建完成"
}

# 创建 XCFramework
create_xcframework() {
    log_info "创建 XCFramework..."

    local FRAMEWORK_NAME="libssh2"
    local OUTPUT_DIR="$FRAMEWORKS_DIR"

    mkdir -p "$OUTPUT_DIR"

    # 创建临时 framework 结构
    for ARCH in "${ARCHS[@]}"; do
        local INSTALL_DIR="$BUILD_DIR/libssh2-install-${ARCH}"
        local OPENSSL_DIR="$BUILD_DIR/openssl-install-${ARCH}"
        local FRAMEWORK_DIR="$BUILD_DIR/framework-${ARCH}/${FRAMEWORK_NAME}.framework"

        mkdir -p "$FRAMEWORK_DIR/Headers"

        # 复制头文件
        cp -r "$INSTALL_DIR/include/libssh2.h" "$FRAMEWORK_DIR/Headers/"
        cp -r "$INSTALL_DIR/include/libssh2_publickey.h" "$FRAMEWORK_DIR/Headers/" 2>/dev/null || true
        cp -r "$INSTALL_DIR/include/libssh2_sftp.h" "$FRAMEWORK_DIR/Headers/" 2>/dev/null || true

        # 合并静态库（libssh2 + OpenSSL）
        libtool -static -o "$FRAMEWORK_DIR/${FRAMEWORK_NAME}" \
            "$INSTALL_DIR/lib/libssh2.a" \
            "$OPENSSL_DIR/lib/libssl.a" \
            "$OPENSSL_DIR/lib/libcrypto.a"

        # 创建 Info.plist
        cat > "$FRAMEWORK_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>org.libssh2</string>
    <key>CFBundleName</key>
    <string>libssh2</string>
    <key>CFBundleVersion</key>
    <string>${LIBSSH2_VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${LIBSSH2_VERSION}</string>
</dict>
</plist>
EOF
    done

    # 删除旧的 XCFramework
    rm -rf "$OUTPUT_DIR/${FRAMEWORK_NAME}.xcframework"

    # 创建 XCFramework
    xcodebuild -create-xcframework \
        -framework "$BUILD_DIR/framework-arm64/${FRAMEWORK_NAME}.framework" \
        -framework "$BUILD_DIR/framework-x86_64/${FRAMEWORK_NAME}.framework" \
        -output "$OUTPUT_DIR/${FRAMEWORK_NAME}.xcframework"

    log_info "XCFramework 创建完成: $OUTPUT_DIR/${FRAMEWORK_NAME}.xcframework"
}

# 验证
verify() {
    log_info "验证 XCFramework..."

    local XCFRAMEWORK="$FRAMEWORKS_DIR/libssh2.xcframework"

    if [ -d "$XCFRAMEWORK" ]; then
        log_info "XCFramework 结构:"
        find "$XCFRAMEWORK" -type f -name "*.a" -o -name "libssh2" | head -20

        # 检查架构
        for ARCH in "${ARCHS[@]}"; do
            local LIB="$XCFRAMEWORK/macos-${ARCH}/libssh2.framework/libssh2"
            if [ -f "$LIB" ]; then
                log_info "检查 ${ARCH} 架构..."
                lipo -info "$LIB"
            fi
        done

        log_info "✅ XCFramework 验证通过"
    else
        log_error "XCFramework 创建失败"
        exit 1
    fi
}

# 清理临时文件
cleanup() {
    log_info "清理临时文件..."
    # 保留 XCFramework，删除构建目录
    # rm -rf "$BUILD_DIR"
    log_info "构建目录保留在: $BUILD_DIR"
}

# 主函数
main() {
    log_info "=========================================="
    log_info "libssh2 XCFramework 构建脚本"
    log_info "OpenSSL: ${OPENSSL_VERSION}"
    log_info "libssh2: ${LIBSSH2_VERSION}"
    log_info "目标: macOS ${MACOS_DEPLOYMENT_TARGET}+ (arm64, x86_64)"
    log_info "=========================================="

    clean
    download_sources

    # 构建每个架构
    for ARCH in "${ARCHS[@]}"; do
        build_openssl "$ARCH"
        build_libssh2 "$ARCH"
    done

    create_xcframework
    verify
    cleanup

    log_info "=========================================="
    log_info "🎉 构建完成！"
    log_info "XCFramework 位置: $FRAMEWORKS_DIR/libssh2.xcframework"
    log_info "=========================================="
}

# 运行
main "$@"
