#!/bin/bash
# archive_appstore.sh — ShellMate App Store 版打包脚本
# 用法：./Scripts/archive_appstore.sh
# 前置条件：Xcode Command Line Tools + 有效的 App Store 证书和 Provisioning Profile

set -e

SCHEME="ShellMate"
PROJECT="ShellMate/ShellMate.xcodeproj"
ARCHIVE_PATH="build/ShellMate-AppStore.xcarchive"
EXPORT_PATH="build/ShellMate-AppStore"
EXPORT_OPTIONS="Scripts/ExportOptions-AppStore.plist"

echo "=== ShellMate App Store Archive ==="
echo "方案: $SCHEME"
echo "归档路径: $ARCHIVE_PATH"

# 清理旧构建
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

# 归档（注入 APP_STORE_BUILD 编译条件）
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS="APP_STORE_BUILD RELEASE" \
    CODE_SIGN_IDENTITY="Apple Distribution" \
    archive

echo "✅ 归档完成: $ARCHIVE_PATH"

# 导出（需要 ExportOptions.plist）
if [ -f "$EXPORT_OPTIONS" ]; then
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
        /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
        -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS"
    echo "✅ 导出完成: $EXPORT_PATH"
else
    echo "⚠️  未找到 $EXPORT_OPTIONS，跳过导出步骤"
    echo "   请创建 ExportOptions-AppStore.plist 后重新运行"
fi
