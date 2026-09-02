#!/bin/bash
# 快速构建签名并公证的 DMG
# Legacy compatibility wrapper. New builds should use:
#   ./build-macos.sh release [options]
# 使用预配置的凭据

set -e

echo "mac-build-signed.sh is deprecated; use ./build-macos.sh release" >&2

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 你的 Apple 凭据配置
KEYCHAIN_PROFILE="zimaos-notarytool"

# 查找签名身份
echo "🔍 查找可用的签名身份..."
SIGNING_IDENTITIES=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1)

if [ -z "$SIGNING_IDENTITIES" ]; then
    echo "❌ 未找到 Developer ID Application 证书"
    echo ""
    echo "请先安装开发者证书，或者使用未签名模式："
    echo "  ./mac-build-dmg.sh"
    exit 1
fi

# 提取签名身份
SIGNING_IDENTITY=$(echo "$SIGNING_IDENTITIES" | sed -n 's/.*"\(.*\)".*/\1/p')

echo "✅ 找到签名身份: $SIGNING_IDENTITY"
echo ""

# 检查是否已配置公证凭据
if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" >/dev/null 2>&1; then
    echo "⚠️  未找到公证配置: $KEYCHAIN_PROFILE"
    echo ""
    echo "请先运行配置脚本："
    echo "  ./setup-notarization.sh"
    echo ""
    read -p "是否继续构建（不公证）？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    NOTARIZE_ARG=""
else
    echo "✅ 找到公证配置: $KEYCHAIN_PROFILE"
    NOTARIZE_ARG="--notarize-profile=$KEYCHAIN_PROFILE"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 开始构建签名的 DMG"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 调用主构建脚本
# shellcheck disable=SC2086
"$SCRIPT_DIR/mac-build-dmg.sh" \
    --signing-identity="$SIGNING_IDENTITY" \
    $NOTARIZE_ARG \
    "$@"
