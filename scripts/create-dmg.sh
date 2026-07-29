#!/bin/bash
#
# create-dmg.sh
# 从 Xcode 导出的 GoldRun.app 制作 DMG 安装包
#
# 用法:
#   ./scripts/create-dmg.sh /path/to/GoldRun.app
#
# 如果不传参数，自动查找最新的 Xcode 构建产物:
#   GoldRun YYYY-MM-DD HH-MM-SS/GoldRun.app
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 查找最新的 Xcode 构建产物
find_latest_app() {
  local latest_dir
  latest_dir=$(ls -dt "$SCRIPT_DIR"/GoldRun\ 2* 2>/dev/null | head -1 || true)
  if [ -n "$latest_dir" ] && [ -d "$latest_dir/GoldRun.app" ]; then
    echo "$latest_dir/GoldRun.app"
  fi
}

APP_PATH="${1:-}"
if [ -z "$APP_PATH" ]; then
  APP_PATH=$(find_latest_app)
  if [ -z "$APP_PATH" ]; then
    echo "❌ 找不到构建产物"
    echo "用法: $0 /path/to/GoldRun.app"
    echo "或在 Xcode 构建后直接运行 $0"
    exit 1
  fi
  echo "🔍 自动找到: $APP_PATH"
fi

if [ ! -d "$APP_PATH" ]; then
  echo "❌ 找不到 $APP_PATH"
  echo "用法: $0 /path/to/GoldRun.app"
  exit 1
fi

VOLUME_NAME="GoldRun"
DMG_NAME="GoldRun.dmg"
DMG_DIR=$(mktemp -d)

echo "📦 正在制作 DMG..."

# 复制 app 和 Applications 快捷方式
cp -R "$APP_PATH" "$DMG_DIR/GoldRun.app"
ln -s /Applications "$DMG_DIR/Applications"

# 创建 DMG（输出到脚本所在项目根目录）
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_DIR" \
  -ov \
  -format UDZO \
  "$SCRIPT_DIR/$DMG_NAME"

# 清理
rm -rf "$DMG_DIR"

echo "✅ 已生成: $SCRIPT_DIR/$DMG_NAME"
