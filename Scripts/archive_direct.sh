#!/bin/bash
# archive_direct.sh — ShellMate Direct（官网 DMG）版打包 + 公证脚本
# 用法：./Scripts/archive_direct.sh
# 前置条件：Developer ID Application 证书 + Apple ID App 专用密码（存入 Keychain）

set -e

SCHEME="ShellMate"
PROJECT="ShellMate/ShellMate.xcodeproj"
ARCHIVE_PATH="build/ShellMate-Direct.xcarchive"
EXPORT_PATH="build/ShellMate-Direct"
APP_PATH="$EXPORT_PATH/ShellMate.app"
DMG_PATH="build/ShellMate-Direct.dmg"
EXPORT_OPTIONS="Scripts/ExportOptions-Direct.plist"

# 公证所需（请替换为实际值）
APPLE_ID="${APPLE_ID:-your@apple.com}"
TEAM_ID="${TEAM_ID:-XXXXXXXXXX}"
KEYCHAIN_PROFILE="${NOTARY_PROFILE:-ShellMate-Notary}"

echo "=== ShellMate Direct Archive ==="
echo "方案: $SCHEME"
echo "归档路径: $ARCHIVE_PATH"

# 清理旧构建
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$DMG_PATH"

# 归档（不注入 APP_STORE_BUILD，使用 Direct 版 entitlements）
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    CODE_SIGN_ENTITLEMENTS="ShellMate/ShellMate-Direct.entitlements" \
    archive

echo "✅ 归档完成: $ARCHIVE_PATH"

# 导出
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
fi

# 公证（需要提前通过 xcrun notarytool store-credentials 存储凭据）
if [ -d "$APP_PATH" ]; then
    echo "📝 开始公证..."
    xcrun notarytool submit "$APP_PATH" \
        --keychain-profile "$KEYCHAIN_PROFILE" \
        --wait

    echo "📎 钉合公证凭单..."
    xcrun stapler staple "$APP_PATH"

    echo "✅ 公证完成"
else
    echo "⚠️  未找到 $APP_PATH，跳过公证步骤"
fi

# 创建 DMG（需要 create-dmg：brew install create-dmg）
if command -v create-dmg &>/dev/null && [ -d "$APP_PATH" ]; then
    create-dmg \
        --volname "ShellMate" \
        --background "Scripts/dmg-background.png" \
        --window-pos 200 120 \
        --window-size 800 400 \
        --icon-size 100 \
        --icon "ShellMate.app" 200 190 \
        --hide-extension "ShellMate.app" \
        --app-drop-link 600 190 \
        "$DMG_PATH" \
        "$APP_PATH"
    echo "✅ DMG 创建完成: $DMG_PATH"
else
    echo "⚠️  create-dmg 未安装或 App 未找到，跳过 DMG 创建"
    echo "   安装：brew install create-dmg"
fi
