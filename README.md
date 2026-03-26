# Daily 365 📔

**你的认知卸载与状态追踪伙伴**

Daily 365 是一款 macOS 原生日记应用，帮助你随手记录想法、追踪情绪与效率节奏，并通过 AI 发现日记中的隐藏关联。所有数据 100% 存储在本地，不上传任何服务器。

## ✨ 功能亮点

### 📝 记录
随手写下想法，AI 自动整理文字、提炼标签，打卡效率与情绪。

### 📅 日记
月历视图追踪每日记录，情绪与效率节奏可视化，支持关键字搜索日记档案。

### 💡 灵光
AI 周报总结本周心路并给出建议，智能问答随时与过去的自己对话。

### 🔮 回响
AI 发现日记中的隐藏关联——成长闭环、情绪解药、行为规律洞察。

### 🔒 隐私优先
- 所有日记数据仅存于浏览器本地 IndexedDB
- 无服务器、无数据上传、无追踪
- AI API Key 仅保存在本地

### 🤖 多 AI 模型支持
DeepSeek / OpenAI / Claude / Gemini / Kimi / 通义千问 / 腾讯混元 / 自定义 API

### 🎤 语音输入
原生 macOS Speech 框架，支持中文语音转文字。

### 💾 数据管理
JSON 完整备份与恢复，Word (.docx) 日记导出。

### 🌙 深色模式
浅色 / 深色双主题，跟随系统或手动切换。

## 🚀 快速开始

### 方式一：直接下载

从 [Release 页面](../../releases) 下载最新的 `Daily365-v1.0.0.dmg`，打开后将 Daily365 拖入「应用程序」文件夹即可。

### 方式二：源码构建

```bash
git clone https://github.com/yyangchen/Daily365.git
cd Daily365
bash build.sh
```

构建完成后，`Daily365.app` 会出现在项目根目录。

## ⚠️ 首次打开需要授权

> **这是正常现象，不是安全问题。**

Daily365 是一款开源免费应用，由独立开发者构建。由于没有加入 Apple 开发者计划（年费 $99），应用未经 Apple 公证签名。macOS 的 Gatekeeper 安全机制会对所有未公证的应用弹出拦截提示——这不代表应用有任何安全风险，只是 Apple 无法验证开发者身份而已。

你可以在本仓库查看完整源码，确认应用安全后，按以下步骤授权打开：

### 方法一：系统设置授权（推荐）

1. 双击打开 `Daily365.app`，系统会提示 **「已阻止 "Daily365" 以保护 Mac」**
2. 打开 **「系统设置」→「隐私与安全性」**
3. 向下滚动，找到提示 **「已阻止 "Daily365" 以保护 Mac。」**，点击右侧的 **「仍要打开」**
4. 在弹出的确认窗口中点击 **「仍要打开」**，输入密码即可

### 方法二：右键打开

1. 在「应用程序」文件夹中找到 `Daily365.app`
2. **按住 Control 键并点击**（或右键点击）→ 选择 **「打开」**
3. 在弹窗中点击 **「打开」**

### 方法三：终端命令（一行搞定）

```bash
xattr -cr /Applications/Daily365.app
```

执行后直接双击打开即可，不会再弹出任何提示。

> 💡 **授权只需一次。** 后续打开 Daily365 不会再出现安全提示。

## 📁 项目结构

```
Daily365/
├── Sources/Daily365/
│   ├── Daily365App.swift        # 应用入口、窗口与菜单
│   ├── WebViewContainer.swift   # WebView 容器与 Coordinator
│   ├── BridgeHandler.swift      # JS ↔ Native 桥接
│   ├── FileStore.swift          # 数据持久化、导入导出
│   ├── SpeechRecognizer.swift   # 原生中文语音识别
│   ├── Daily365.entitlements    # 权限声明
│   ├── Assets.xcassets/         # 应用图标
│   └── Resources/
│       └── index.html           # 完整前端 UI（HTML/CSS/JS）
├── Package.swift                # Swift Package Manager 配置
├── build.sh                     # 一键构建脚本
├── LICENSE                      # MIT 许可证
├── CHANGELOG.md                 # 版本更新日志
└── README.md
```

## 🛠 技术栈

| 层级 | 技术 |
|---|---|
| 应用框架 | Swift + SwiftUI |
| UI 渲染 | WKWebView + 本地 HTML/CSS/JS |
| 桥接通信 | WKScriptMessageHandler |
| 本地存储 | IndexedDB |
| 语音识别 | Apple Speech Framework |
| 外部依赖 | 无 — 纯 Apple 原生框架 |

## 💻 系统要求

- macOS 14.0 (Sonoma) 或更高版本

## 📄 许可证

[MIT License](LICENSE)

## 🙏 致谢

- 设计灵感来自 [Anthropic Design System](https://docs.anthropic.com/en/docs/build-with-claude/design)
