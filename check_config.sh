#!/bin/bash

echo "🔍 FilesManage 配置检查工具"
echo "================================"
echo ""

PROJECT_DIR="/Users/bolin/Movies/Project/FilesManage"
ENTITLEMENTS="$PROJECT_DIR/FilesManage/FilesManage.entitlements"

# 检查 1: Entitlements 文件
echo "1️⃣ 检查 Entitlements 文件..."
if [ -f "$ENTITLEMENTS" ]; then
    echo "   ✅ 文件存在: $ENTITLEMENTS"
    
    if grep -q "<key>com.apple.security.app-sandbox</key>" "$ENTITLEMENTS"; then
        if grep -A1 "com.apple.security.app-sandbox" "$ENTITLEMENTS" | grep -q "<false/>"; then
            echo "   ✅ App Sandbox 已禁用"
        else
            echo "   ⚠️  App Sandbox 已启用（这可能导致文件访问问题）"
            echo "   建议：将 <true/> 改为 <false/>"
        fi
    else
        echo "   ⚠️  未找到 App Sandbox 配置"
    fi
else
    echo "   ❌ 文件不存在: $ENTITLEMENTS"
    echo "   建议：创建 entitlements 文件"
fi
echo ""

# 检查 2: 测试文件夹访问
echo "2️⃣ 测试文件夹访问权限..."
test_folders=(
    "$HOME/Desktop:桌面"
    "$HOME/Documents:文档"
    "$HOME/Downloads:下载"
    "/Applications:应用程序"
)

for folder_info in "${test_folders[@]}"; do
    IFS=':' read -r folder name <<< "$folder_info"
    if [ -d "$folder" ]; then
        if [ -r "$folder" ]; then
            echo "   ✅ $name ($folder) - 可访问"
        else
            echo "   ❌ $name ($folder) - 无法访问"
        fi
    else
        echo "   ⚠️  $name ($folder) - 不存在"
    fi
done
echo ""

# 检查 3: Xcode 构建产物
echo "3️⃣ 检查最近的构建..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "FilesManage.app" -type d 2>/dev/null | head -1)
if [ -n "$APP_PATH" ]; then
    echo "   ✅ 找到应用: $APP_PATH"
    
    # 检查应用的 entitlements
    if [ -f "$APP_PATH/Contents/Info.plist" ]; then
        echo "   ✅ Info.plist 存在"
    fi
    
    # 检查代码签名
    codesign -d --entitlements - "$APP_PATH" 2>/dev/null > /tmp/app_entitlements.xml
    if [ -f /tmp/app_entitlements.xml ]; then
        if grep -q "com.apple.security.app-sandbox" /tmp/app_entitlements.xml; then
            if grep -A1 "com.apple.security.app-sandbox" /tmp/app_entitlements.xml | grep -q "<false/>"; then
                echo "   ✅ 应用的 App Sandbox 已禁用"
            else
                echo "   ⚠️  应用的 App Sandbox 已启用"
            fi
        else
            echo "   ✅ 应用没有 App Sandbox 限制"
        fi
    fi
else
    echo "   ⚠️  未找到构建的应用"
    echo "   建议：在 Xcode 中构建项目"
fi
echo ""

# 检查 4: 系统版本
echo "4️⃣ 系统信息..."
sw_vers
echo ""

# 总结
echo "================================"
echo "📋 建议："
echo ""
echo "如果看到任何 ❌ 或 ⚠️："
echo "1. 确保 Entitlements 文件中 App Sandbox 设置为 false"
echo "2. 在 Xcode 中删除 App Sandbox capability"
echo "3. 清理构建：xcodebuild clean"
echo "4. 重新构建项目"
echo ""
echo "如果所有检查都通过但仍然无法访问文件："
echo "1. 查看 Xcode 控制台的错误日志"
echo "2. 尝试从终端启动应用"
echo "3. 检查系统设置 > 隐私与安全性"
echo ""
