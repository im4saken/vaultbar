# VaultBar

![banner](assets/banner.png)

VaultBar 是一个 macOS 菜单栏 API Key 管理器。它支持搜索、复制、编辑和导入 API Key，数据保存在系统 Keychain 和加密元数据中。

## 下载

如果你只想直接使用，不需要自己编译，可以到 GitHub Releases 下载预编译版本：

[VaultBar v1.0.0](https://github.com/im4saken/vaultbar/releases/tag/v1.0.0)

## 功能

- 菜单栏一键打开搜索栏，快速查找 API Key
- 复制到剪贴板后自动清理
- Settings 中可以编辑、删除、批量导入 Key
- 支持锁定和解锁已保存的 Key

## 安装与运行

### 方式一：直接运行

构建并生成可执行 app bundle：

```sh
./scripts/build-app.sh
```

生成结果在：

```text
build/VaultBar.app
```

然后双击打开，或者用命令启动：

```sh
open build/VaultBar.app
```

### 方式二：本地开发

如果你想用 Swift Package 方式编译：

```sh
swift build
```

## 使用教学

### 1. 打开搜索栏

点击菜单栏里的 VaultBar 图标，会弹出搜索栏。第一次启动时，macOS 可能会要求授权。

![启动后解锁](assets/launch_unlock.png)

### 2. 搜索和复制

在搜索框里输入 Key 名称，回车会复制当前选中的 Key。也可以点击结果列表里的条目进行选择。

![搜索](assets/search.png)

### 3. 添加 Key

在搜索栏里点击 `+`，会打开新增窗口。填入名称和 API Key 后保存。

![添加](assets/add.png)

### 4. 管理 Key

打开 Settings 可以编辑或删除已有 Key，也可以调整剪贴板自动清理时间。

### 5. 锁定和解锁

在 Settings 左上角点击锁头图标，可以解锁查看或编辑 Key。再次点击会重新锁定并清空当前解锁状态。

![解锁](assets/unlock.png)

### 6. 批量导入

在 Settings 中使用批量导入，选择 `.txt`、`.csv` 或 `.md` 文件。每一行格式如下：

```text
label,api_key
```

支持跳过以 `#` 或 `//` 开头的注释行。

## 为什么启动时会要求输入密码

VaultBar 把 API Key 存在系统 Keychain 里。启动时需要访问这些 Keychain 条目来读取元数据、恢复已保存的 Key，或者准备 Settings 里的编辑视图。macOS 会在某些情况下要求你输入登录密码或通过系统验证，这是系统在确认“当前应用可以读取这些受保护的数据”，不是 VaultBar 自己保存了额外密码。

如果你刚重启过电脑、刚登录账户，或者 Keychain 还没有解锁，第一次访问时出现密码提示是正常的。

## 说明

- API Key 保存在系统 Keychain。
- 搜索元数据使用加密 JSON 存在 Application Support。
- 本项目是 macOS 菜单栏应用，`LSUIElement = true`。

## 项目文件

- `Sources/VaultBar/Security/KeychainHelper.swift`: Keychain 读写
- `Sources/VaultBar/Storage/MetadataStore.swift`: 加密元数据存储
- `Sources/VaultBar/App/KeyRepository.swift`: 搜索、复制、导入逻辑
- `Sources/VaultBar/Window/CapsulePanel.swift`: 菜单栏搜索浮窗
- `Sources/VaultBar/UI/CapsuleSearchView.swift`: 搜索栏界面
- `Sources/VaultBar/UI/SettingsView.swift`: Settings 管理界面
