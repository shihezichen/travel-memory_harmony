# travel-memory_harmony

[Travel Memory](https://github.com/shihezichen/travel-memory) 的鸿蒙 HarmonyOS 客户端壳应用。

应用已自托管在云主机上，本 App 通过 **ArkWeb (Web 组件)** 全屏加载 `https://top001.xin`，
把既有 Web 服务直接变成一个鸿蒙原生 App（路线：远程服务 + 本地 Web 壳）。
相比浏览器，壳层补齐了网站自身无法提供的原生能力。

## 功能

- **全屏 ArkWeb** 加载 `https://top001.xin`，深/浅色跟随系统
- **沉浸式布局**：网页内容延伸到状态栏之下（edge-to-edge），页面用 safe-area 避让系统栏
- **加载体验**：顶部细进度条；首屏连接动画；连接失败/证书错误时显示可重试的错误页
- **下拉刷新**（`Refresh` + `WebviewController.refresh`）
- **系统返回手势/按键**：优先回退网页历史，回到首页后才退出 App
- **外链处理**：站外 `http(s)` 与 `mailto:` / `tel:` / `sms:` 链接交给系统浏览器或对应应用打开
- **媒体下载**：网页触发的下载（照片/视频「保存到本地」）由 `WebDownloadDelegate` 接管，
  保存到应用沙箱 `filesDir/downloads/`，完成后 Toast 提示文件名
- **上传**：网页 `<input type=file>` 直接唤起系统文件/相册选择器（ArkWeb 默认能力）
- **权限**：定位、相机、麦克风的运行时申请，网页请求时按需授予（`onGeolocationShow` / `onPermissionRequest`）
- **Web 引擎调优**：DOM Storage / Database / 混合内容 / 自动播放 / 自定义 User-Agent 标记
- `INTERNET`、网络状态、定位、相机、麦克风权限声明；应用数据备份/恢复（EntryBackupAbility）

## 环境要求

- DevEco Studio 6.0（本仓库在 26.0.0.851 上验证）
- HarmonyOS SDK：`compatibleSdkVersion 6.1.1(24)` / `targetSdkVersion 26.0.0`
- Stage 模型

## 构建与运行

### 方式一：DevEco Studio（推荐）

1. 用 DevEco Studio 打开本项目；
2. `File > Project Structure > Signing Configs` 配置签名（自用可选「自动签名」）；
3. 连接鸿蒙设备或模拟器，点击 Run，或 `Build > Build Hap(s)/APP(s)`。

### 方式二：命令行

DevEco Studio 自带了 `hvigorw`、`ohpm` 与 JBR，命令行构建时把 SDK 和 JDK 指给它即可：

```bash
# 1. 安装依赖（首次）
"<DevEco>/tools/ohpm/bin/ohpm.bat" install --all

# 2. 打包 HAP
export DEVECO_SDK_HOME="<DevEco>/sdk"      # Windows 下为 D:\Program Files\Huawei\DevEco Studio\sdk
export JAVA_HOME="<DevEco>/jbr"
export PATH="$JAVA_HOME/bin:$PATH"
"<DevEco>/tools/hvigor/bin/hvigorw.bat" assembleHap --no-daemon
```

产物位于 `entry/build/default/outputs/default/`（未配置签名时为 `entry-default-unsigned.hap`）。

> 若要让仓库根目录下的 `hvigorw` 可用，可用 DevEco Studio 打开一次项目，IDE 会生成
> 对应的 wrapper；或直接把上面的 `<DevEco>/tools/hvigor/bin/hvigorw` 加入 PATH。

## 结构

```
AppScope/app.json5                          # 应用级配置（bundleName: xin.top001.travelmemory）
AppScope/resources/base/media/              # 应用分层图标（background / foreground）
entry/src/main/module.json5                 # 权限 / Ability / 备份配置
entry/src/main/ets/entryability/            # Ability 入口（窗口准备、加载 page）
entry/src/main/ets/entrybackupability/      # 应用数据备份/恢复
entry/src/main/ets/pages/Index.ets          # ArkWeb 壳页面（服务器地址在此修改）
entry/src/main/resources/base/media/        # 启动图标等资源
entry/src/test/                             # 本地单元测试
entry/src/ohosTest/                         # 设备端测试
hvigorfile.ts / hvigor/                     # 构建配置
```

修改服务器地址：`entry/src/main/ets/pages/Index.ets` 顶部的 `SERVER_URL` 与 `SERVER_HOST`。

## 权限说明

| 权限 | 用途 |
| --- | --- |
| `ohos.permission.INTERNET` | 加载远程网页与媒体 |
| `ohos.permission.GET_NETWORK_INFO` | 网络状态检测 |
| `ohos.permission.APPROXIMATELY_LOCATION` / `ohos.permission.LOCATION` | 地图定位、记录旅行足迹 |
| `ohos.permission.CAMERA` | 拍照/录像后上传 |
| `ohos.permission.MICROPHONE` | 录制带声音的视频 |

定位、相机、麦克风均为用户授权权限，只在网页真正请求时申请一次。

## 后续可扩展

- 下载文件「另存到相册/文件管理」并直接在 App 内预览
- 分享面板、桌面快捷方式
- 推送（行程提醒、Agent 结果通知）

## License

[MIT](./LICENSE)（与上游项目一致）
