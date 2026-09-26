# 拾序工作台 · Shixu Workspace

把一个任务需要的网页、文件、文件夹和应用收在同一个场景里，下次一键打开，继续手头的工作。

A local macOS workspace launcher built with SwiftUI and AppKit. Group websites, files, folders, and apps into reusable scenes, then open them together. The current interface is in Chinese.

## 第一版功能

- 创建和编辑工作场景，选择资料、调整打开顺序。
- 收录网页、文件、文件夹和应用，搜索名称、路径和类型。
- 一键打开整组资料，记录最近成功打开的入口。
- 菜单栏入口，`⌘⇧空格` 呼出，`⌘K` 搜索，`⌘N` 新建场景。
- 本地自动保存、撤销上一次修改、JSON 备份导入和导出。
- 快捷打开桌面、下载文件夹，建立今日工作场景。

首次启动包含“写公众号”和“AI 学习”两个示例场景，以及 ChatGPT、微信公众号后台和 GitHub 三个网页入口。可以直接修改，也可以创建自己的场景。

## 下载与使用

第一版下载包面向 **Apple 芯片 Mac，macOS 14 或更高版本**。

1. 在本仓库的 [Releases](https://github.com/lianyongqiang/shixu-workspace/releases) 下载应用 ZIP。
2. 解压，打开“拾序工作台.app”，或拖入“应用程序”文件夹。
3. 选择场景，点击“添加”放入自己的资料，再点击“一键打开”。

应用运行无需 Node、Python 或开发工具。详细操作见 [使用说明](使用说明.md)。

当前下载包使用本地签名，**未做 Apple 公证**，其他 Mac 可能显示安全提示；也可以按下面的步骤自行构建。Intel Mac 尚未实测。

## 从源码构建

需要 macOS 14+、Swift 6 工具链（Xcode 或 Apple Command Line Tools）和 Python 3。Python 只用于构建工具链兼容配置，不是应用运行依赖。

```bash
git clone https://github.com/lianyongqiang/shixu-workspace.git
cd shixu-workspace
bash scripts/test.sh
bash scripts/build.sh
```

产物位于 `dist/拾序工作台.app` 及同目录的 ZIP 包，架构跟随构建机器。构建脚本直接调用系统 Swift 编译器；缓存与工具链兼容文件都在项目的 `.cache/` 和 `.build/`，不会修改系统工具链。

核心检查覆盖资料校验、中文数据保存、备份恢复、导入校验、搜索与原文件保护。第一版在 Apple 芯片 Mac、macOS 15.2 上通过 12 项检查，见 [验证记录](验证记录.md)。

## 数据与范围

工作台数据保存在本机：

```text
~/Library/Application Support/ShixuWorkspace/workspace.json
~/Library/Application Support/ShixuWorkspace/workspace.previous.json
```

应用没有账号系统、云同步或分析上报。打开网页时，由浏览器访问对应网站。文件通过系统选择窗口手动添加；应用不扫描全盘，也不自动收集浏览器标签。

“恢复工作”指重新打开已保存的入口，不恢复窗口位置、网页输入或未保存的文档。移除入口不会删除原文件。JSON 备份含资料名称和本地路径，不包含文件内容；分享备份前请检查其中的信息。

网页仅接受 HTTP/HTTPS 地址，不运行自定义脚本。无法打开某项时会提示，其余资料继续处理。数据写入采用原子保存，读取损坏文件时不会静默覆盖，恢复备份会保留原件。

## 项目结构

```text
Sources/DeskCore/       数据模型、搜索、校验和持久化
Sources/Shixu/          原生界面、文件选择、系统打开、菜单栏
Tests/DeskCoreChecks/  可独立运行的核心检查
Resources/             应用元信息
scripts/               测试、构建和图标生成
```

欢迎提交 Issue 或 Pull Request。复现问题时请附 macOS 版本和操作步骤，并去掉个人文件路径、备份内容及凭据。

## 许可证

[MIT](LICENSE) © 2026 lianyongqiang
