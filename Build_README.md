# FilesManage

一个基于 SwiftUI 的 macOS 文件管理器，支持双栏模式、标签与网址管理、预览与常用文件操作。用于更高效地在 mac 上浏览、搜索、排序和管理文件。

## 关于
- 项目主页（GitHub）：https://github.com/shiyaaini/MacOSFilesManage
- 视频与更新（哔哩哔哩）：https://space.bilibili.com/519965290?
- 项目定位：简洁高效的 macOS 文件管理器，强调双栏操作与预览能力。
- 维护方向：持续优化交互、性能与本地化，欢迎反馈与贡献。

## 功能特性
- 双栏模式：点击任意栏内区域即可设为活动栏，并以边框高亮当前栏；顶部工具栏对活动栏生效。
- 搜索与排序（逐栏）：每个栏独立的搜索框与排序设置（名称/时间/大小 + 升降序）。
- 视图模式：列表/网格两种视图，缩略图大小可调，并为每个文件夹记忆视图模式与网格大小。
- 面包屑导航：快速回溯路径，支持复制当前路径到剪贴板。
- 标签系统：
  - 可为 .app 应用添加/移除标签
  - 标签下支持添加网址，网址以“虚拟文件项”呈现，可重命名标题、更换图标、打开链接
  - 标签网址支持搜索与排序，与普通文件一致地展示与选择
- 右键菜单（上下文菜单）：复制/剪切/粘贴、复制路径、终端打开、重命名、属性、压缩/解压、打开方式等。
- 预览面板（可选）：图片、PDF、文本等类型的快速预览。
- 拖拽支持：文件拖拽，表格/网格均可操作；支持将外部文件拖入当前目录。
- 本地化：中文与英文两种语言，界面文本基于 Localizable.strings 管理。

## 快速开始
### 环境要求
- macOS 13+（建议 13.0 或更高）
- Xcode 15+（含 Swift 5.9+）

### 构建与运行
1. 使用 Xcode 打开项目 `FilesManage.xcodeproj`
2. 选择 Scheme `FilesManage`
3. 直接运行（⌘R）

或使用命令行：
```bash
xcodebuild -project FilesManage.xcodeproj -scheme FilesManage -configuration Debug -destination "platform=macOS" build
```
构建：
```bash
# 生成带拖拽安装提示的 DMG（推荐分发给测试用户）
bash ./build_app.sh --clean --dmg

# 生成 PKG 安装包（包含安装向导）
bash ./build_app.sh --clean --pkg

# 同时生成 DMG 与 PKG
bash ./build_app.sh --clean --dmg --pkg
#更改版本
xcrun agvtool new-marketing-version 1.0.1
```
打包产物默认输出到 `./dist/` 目录：
- 应用：`./dist/FilesManage.app`
- 压缩包：`./dist/FilesManage.zip`
- 镜像：`./dist/FilesManage.dmg`（包含 Applications 快捷方式，拖拽即可安装）
- 安装包：`./dist/FilesManage.pkg`（双击进入安装向导，自动安装到 /Applications）

### 安装说明
- DMG：双击打开镜像，拖拽 FilesManage.app 到 Applications 即完成安装
- PKG：双击 `.pkg`，按向导“继续→安装”即可自动安装到 /Applications

### 可选：安装包签名与公证
如需为 PKG 签名（更利于系统信任与分发），可指定证书名称：
```bash
SIGN_ID="Developer ID Installer: Your Name (TEAMID)" bash ./build_app.sh --pkg
```
如果出现 Gatekeeper 提示“已损坏无法打开”，可先移除隔离属性后再打开（仅开发测试环境）：
```bash
xattr -cr /path/to/FilesManage.app
```
## 主要交互说明
- 双栏切换：点击栏内任意区域（包括面包屑/列表空白/文件行/网格项）即可设为活动栏。
- 搜索与排序：工具栏上的搜索与排序绑定至“当前活动栏”，两栏互不干扰。
- 选择与多选：单击选中；Shift 连选区间；⌘ 追加/取消选择；双击打开文件或应用。
- 终端与路径：支持在当前路径打开终端；面包屑处可复制当前路径。
- 标签与网址：
  - 在侧边栏管理标签；为 .app 应用添加/移除标签
  - 在标签中添加网址，支持重命名标题与更换图标
  - 网址以虚拟文件项显示，可与普通文件一致地选择/排序/搜索

## 偏好与持久化
- 视图模式与缩略图大小：对每个文件夹记忆列表/网格与缩略图大小设置（存储于 AppPreferences）。
- 标签与网址元数据：标题与图标的元数据存储于 AppPreferences（UserDefaults），支持随时更新。
- 语言与主题：通过 AppPreferences 切换语言与主题；语言变更会通知刷新界面。

## 框架与依赖
- SwiftUI / AppKit（界面与系统集成）
- QuickLookThumbnailing（生成缩略图）
- UniformTypeIdentifiers（文件拖拽与类型识别）
- PDFKit（PDF 预览）

## 常见问题
- 无法访问文件夹：首次进入某些目录可能需要授权，界面会给出“请求访问权限”的提示按钮。
- 网址图标：支持 PNG/JPG/ICNS/GIF/TIFF；若站点未提供 favicon，会回退到默认链接图标。


## 贡献
欢迎提 Issue 或提交 PR 改进双栏交互、预览能力与标签网址体验。
