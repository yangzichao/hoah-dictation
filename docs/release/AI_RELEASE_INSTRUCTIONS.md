# AI Agent: HoAh 版本发布指令

> 本文档专为 AI Agent 设计，提供清晰的版本发布步骤。

## 🎯 目标
发布 HoAh 的新版本，触发自动构建和 GitHub Release。

## 📍 需要修改的文件

### 文件清单（共 4 个）

1. **Config/Info.plist**
2. **HoAh.xcodeproj/project.pbxproj**
3. **appcast.xml**
4. **RELEASE_NOTES.md**（可选）

## 🔢 版本号格式

### 输入格式
- 语义化版本：`X.Y.Z`（例如：`3.1.2`）

### 转换规则
- 内部版本号 = `X * 100 + Y * 10 + Z`
- 例如：`3.1.2` → `312`

### 示例
| 语义化版本 | 内部版本号 |
|-----------|-----------|
| 3.1.2 | 312 |
| 3.2.0 | 320 |
| 4.0.0 | 400 |

## 📝 详细修改步骤

### 步骤 1: 修改 Config/Info.plist

**位置**：`Config/Info.plist`

**修改内容**：
```xml
<key>CFBundleShortVersionString</key>
<string>3.1.2</string>  <!-- 改为新版本号 -->

<key>CFBundleVersion</key>
<string>312</string>     <!-- 改为新的内部版本号 -->
```

**查找方式**：
- 搜索 `CFBundleShortVersionString`
- 修改其下一行的 `<string>` 标签内容
- 搜索 `CFBundleVersion`
- 修改其下一行的 `<string>` 标签内容

### 步骤 2: 修改 HoAh.xcodeproj/project.pbxproj

**位置**：`HoAh.xcodeproj/project.pbxproj`

**修改内容**（有 2 处，Debug 和 Release）：
```
MARKETING_VERSION = 3.1.2;        <!-- 改为新版本号 -->
CURRENT_PROJECT_VERSION = 312;    <!-- 改为新的内部版本号 -->
```

**使用 sed 命令快速修改**：
```bash
sed -i '' 's/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = 3.1.2;/g' HoAh.xcodeproj/project.pbxproj
sed -i '' 's/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = 312;/g' HoAh.xcodeproj/project.pbxproj
```

### 步骤 3: 修改 appcast.xml

**位置**：`appcast.xml`

**操作**：在 `<channel>` 标签内的**最前面**（第一个 `<item>` 之前）添加新条目

**模板**：
```xml
<item>
    <title>3.1.2</title>
    <pubDate>Tue, 10 Dec 2025 00:00:00 +0000</pubDate>
    <sparkle:version>312</sparkle:version>
    <sparkle:shortVersionString>3.1.2</sparkle:shortVersionString>
    <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
    <description><![CDATA[
        <h3>What's New in Version 3.1.2</h3>
        <ul>
            <li>Feature or fix description 1</li>
            <li>Feature or fix description 2</li>
            <li>Feature or fix description 3</li>
        </ul>
    ]]></description>
    <enclosure url="https://github.com/yangzichao/hoah-dictation/releases/download/v3.1.2/HoAh-3.1.2.dmg" length="0" type="application/octet-stream" sparkle:edSignature=""/>
</item>
```

**关键字段**：
- `<title>`: 版本号（如 `3.1.2`）
- `<sparkle:version>`: 内部版本号（如 `312`）
- `<sparkle:shortVersionString>`: 版本号（如 `3.1.2`）
- `<enclosure url>`: 必须包含 `v{VERSION}` 和 `HoAh-{VERSION}.dmg`

**注意**：
- 新版本必须在最前面
- 保留旧版本的 `<item>` 条目

### 步骤 4: 更新 RELEASE_NOTES.md（可选）

**位置**：`RELEASE_NOTES.md`

**内容**：描述新版本的更新内容，这将作为 GitHub Release 的描述。

## 🚀 Git 操作

### 提交更改

```bash
# 添加修改的文件
git add Config/Info.plist
git add HoAh.xcodeproj/project.pbxproj
git add appcast.xml
git add RELEASE_NOTES.md  # 如果有修改

# 提交
git commit -m "Bump version to 3.1.2"

# 推送到 main 分支
git push origin main
```

### 创建并推送 Tag（触发自动构建）

```bash
# 创建 tag（格式必须是 v{VERSION}）
git tag -a v3.1.2 -m "Release version 3.1.2"

# 推送 tag（这会触发 GitHub Actions 自动构建）
git push origin v3.1.2
```

**关键点**：
- Tag 格式：`v{VERSION}`（必须以 `v` 开头）
- 例如：`v3.1.2`、`v3.2.0`、`v4.0.0`
- 推送 tag 后会自动触发 `.github/workflows/release.yml`

## 🤖 自动构建流程

推送 tag 后，GitHub Actions 会自动执行：

1. 检出代码
2. 构建 Whisper Framework
3. 构建应用
4. 签名和公证（如果配置了证书）
5. 创建 DMG 文件
6. 创建 GitHub Release
7. 上传 DMG 到 Release

**查看进度**：
- URL: https://github.com/yangzichao/hoah-dictation/actions
- 查找 "Release HoAh" workflow

## ✅ 验证步骤

发布完成后验证：

1. **GitHub Release**：
   - URL: `https://github.com/yangzichao/hoah-dictation/releases/tag/v{VERSION}`
   - 检查是否包含 DMG 文件

2. **DMG 下载链接**：
   - URL: `https://github.com/yangzichao/hoah-dictation/releases/download/v{VERSION}/HoAh-{VERSION}.dmg`
   - 测试是否可以下载

3. **appcast.xml**：
   - URL: `https://raw.githubusercontent.com/yangzichao/hoah-dictation/main/appcast.xml`
   - 检查是否包含新版本信息

## 🔧 使用自动化脚本

项目提供了自动化脚本来简化版本更新：

```bash
# 运行脚本
./scripts/bump-version.sh 3.1.2

# 脚本会自动更新：
# - Config/Info.plist
# - HoAh.xcodeproj/project.pbxproj

# 然后手动更新：
# - appcast.xml
# - RELEASE_NOTES.md

# 最后执行 Git 操作
```

## 🚨 常见错误

### 错误 1: Tag 格式不正确
- ❌ 错误：`3.1.2`、`release-3.1.2`
- ✅ 正确：`v3.1.2`

### 错误 2: 版本号不一致
- 确保 4 个文件中的版本号完全一致
- 语义化版本：`3.1.2`
- 内部版本号：`312`

### 错误 3: appcast.xml 新版本位置错误
- 新版本必须在 `<channel>` 内的最前面
- 不能放在旧版本后面

### 错误 4: 忘记推送代码就推送 tag
- 必须先推送代码到 main 分支
- 然后再推送 tag

## 📋 完整示例

假设要发布版本 `3.1.2`：

```bash
# 1. 使用脚本更新版本号
./scripts/bump-version.sh 3.1.2

# 2. 手动更新 appcast.xml（添加新的 <item>）

# 3. 提交更改
git add Config/Info.plist HoAh.xcodeproj/project.pbxproj appcast.xml
git commit -m "Bump version to 3.1.2"
git push origin main

# 4. 创建并推送 tag
git tag -a v3.1.2 -m "Release version 3.1.2"
git push origin v3.1.2

# 5. 等待自动构建完成（约 10-15 分钟）

# 6. 验证发布
open https://github.com/yangzichao/hoah-dictation/releases/tag/v3.1.2
```

## 📚 相关文件

- **工作流配置**：`.github/workflows/release.yml`
- **详细指南**：`docs/VERSION_RELEASE_GUIDE.md`
- **快速参考**：`RELEASE_QUICK_GUIDE.md`
- **自动化脚本**：`scripts/bump-version.sh`

## 🎓 总结

**核心步骤**：
1. 更新 4 个文件中的版本号
2. 提交并推送到 main
3. 创建并推送 tag（格式：`v{VERSION}`）
4. 等待自动构建完成

**关键点**：
- Tag 格式必须是 `v{VERSION}`
- 版本号必须在所有文件中一致
- appcast.xml 新版本必须在最前面
- 推送 tag 会触发自动构建
