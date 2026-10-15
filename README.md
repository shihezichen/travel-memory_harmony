# travel-memory_harmony

[Travel Memory](https://github.com/shihezichen/travel-memory) 的鸿蒙 HarmonyOS 客户端壳应用。

应用已自托管在云主机上，本 App 通过 **ArkWeb (Web 组件)** 全屏加载 `https://top001.xin`，
把既有 Web 服务直接变成一个鸿蒙原生 App（路线：远程服务 + 本地 Web 壳）。
相比浏览器，壳层补齐了网站自身无法提供的原生能力。

## 与 Web 版的关系

本 App 是一个**壳**：不打包任何网页代码，运行时直接用 ArkWeb 加载线上 `https://top001.xin`。
因此 App 里看到的功能与 Web 版**始终一致** —— 服务器更新后重开 App 即生效，无需重新发版；
反过来，改服务器就等于改 App。

差别只在壳层，以及少数浏览器能力在 ArkWeb 上的降级（已知：`blob:` 触发的下载不走原生下载代理；
File System Access API 不可用；网页 `fullscreen()` 只在 Web 视图内生效）。

## 功能

- **全屏 ArkWeb** 加载 `https://top001.xin`，深/浅色跟随系统
- **沉浸式 + 不遮挡**：窗口 edge-to-edge，页面背景铺满到状态栏底下；同时 App 会把状态栏高度注入网页，
  把网页自己的顶栏（`header` / `.topbar`）推到状态栏之下，并按页面明暗自动切换状态栏图标颜色。
  开关在 `entry/src/main/ets/common/AppConfig.ets` 的 `IMMERSIVE`
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

## 安装到鸿蒙手机

HarmonyOS（NEXT / 纯血鸿蒙）只能安装**已签名**的 HAP，命令行产出的
`entry-default-unsigned.hap` 无法直接安装。签名需要**华为开发者账号**（个人可免费注册，需实名认证）。

### 前置：打开开发者模式与 USB 调试

1. 设置 → 关于手机 → 连续点击「软件版本号」7 次 → 输入锁屏密码，开启开发者模式；
2. 设置 → 系统和更新 → 开发人员选项 → 打开「USB 调试」（可一并打开「仅充电模式下允许 ADB 调试」）；
3. 用数据线连接电脑，手机弹出「是否允许 USB 调试」→ 允许（建议勾选「始终允许」）。

### 方式一：DevEco Studio（推荐，最省事）

1. DevEco Studio 打开本项目，右上角登录华为开发者账号；
2. `File → Project Structure → Signing Configs`，勾选 **Automatically generate signature**，等待生成完成；
3. 顶部设备列表选择已连接的手机，点击 ▶ Run（或 `Build → Build Hap(s)/APP(s) → Build Hap(s)`，
   产物为 `entry/build/default/outputs/default/entry-default-signed.hap`）。

DevEco 会把自动签名材料（`.p12` / `.cer` / `.p7b`）放到 `~/.ohos/config/`，并写入
`build-profile.json5` 的 `signingConfigs`。**该段含证书路径 / 口令（本机加密），不要提交到仓库**
（本仓库里的 `signingConfigs` 保持为 `[]`）。想让它永远不进版本库，可在本机执行一次：

```bash
git update-index --skip-worktree build-profile.json5
```

### 方式二：命令行 hdc

```bash
HDC="<DevEco>/sdk/default/openharmony/toolchains/hdc.exe"

# 1. 确认手机已连接（应能看到 USB 设备，而不是空）
"$HDC" list targets

# 2. 先在 DevEco 里完成过一次自动签名，再打包（产物带 -signed 后缀）
<DevEco>/tools/hvigor/bin/hvigorw.bat assembleHap --no-daemon

# 3. 安装；重复安装用 -r 覆盖
"$HDC" install    entry/build/default/outputs/default/entry-default-signed.hap
"$HDC" install -r entry/build/default/outputs/default/entry-default-signed.hap
```

### 关于系统版本

当前 `compatibleSdkVersion 6.1.1(24)`，即需要 **HarmonyOS 6.1.1（API 24）及以上**。
若要支持更低版本（如 HarmonyOS 5 / API 12），需在 DevEco 的 SDK Manager 中额外安装对应 SDK，
再把 `build-profile.json5` 的 `compatibleSdkVersion` / `targetSdkVersion` 调低后重新编译。
若没有真机，也可用 DevEco Studio 的模拟器（同样需要登录账号）先跑起来。

## 分发给别人的鸿蒙手机

上面那套是**调试签名**：证书里绑了你这台设备的 UDID，装到别人手机上会被拒绝。
要让别人的鸿蒙手机也能装，只有两条路：

| 方式 | 别人怎么拿到 | 说明 |
| --- | --- | --- |
| **上架 AppGallery** | 应用市场里搜到、点安装 | 需要发布证书 + 发布 Profile，提交后要审核 |
| **企业/内部测试分发** | 拿 `.app` 直接装 / 走 AGC 的测试渠道 | 同样需要发布证书；受限分发需要把对方设备加进白名单 |

两种都绕不开**华为开发者账号（需实名）**在 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)
上申请**发布证书（.cer）**和**发布 Profile（.p7b）**——这一步必须你本人操作，我代替不了。

工程侧我已经准备好，拿到证书后只差**填一段配置**：

1. AGC 里「我的应用 → 新建应用」，包名填 `xin.top001.travelmemory`；
2. 「证书、App ID 和 Profile」里生成 **发布证书** 和 **发布 Profile**，下载 `.cer` / `.p7b` / `.p12`；
3. 把 `build-profile.json5` 的 `signingConfigs` 换成发布证书（和调试那段结构一样，
   只是 `certpath` / `profile` / `storeFile` 指向新文件、`keyAlias` 改成发布用的别名）；
4. 打包：

```bash
export DEVECO_SDK_HOME="<DevEco>/sdk"
export JAVA_HOME="<DevEco>/jbr"
"<DevEco>/tools/hvigor/bin/hvigorw.bat" assembleApp --no-daemon
```

产物是 `build/outputs/default/travelmemory-default-signed.app`（`.app` 是上架用的整包，
里面就是 `entry-default-signed.hap`）。上传 AGC 后按提示补应用信息、隐私声明即可提交。

> **`.hap` 与 `.app` 的区别**：`.hap` 是模块包，`hdc install` 装的是它；
> `.app` 是打包给应用市场/分发用的整包，不能直接用 hdc 装。
> 顺带一提，**鸿蒙装不了 APK**，APK 是 Android 的格式；要覆盖 Android 手机请看
> [travel-memory_android](https://github.com/shihezichen/travel-memory_android)。

## 结构

```
AppScope/app.json5                          # 应用级配置（bundleName: xin.top001.travelmemory）
AppScope/resources/base/media/              # 应用分层图标（background / foreground）
entry/src/main/module.json5                 # 权限 / Ability / 备份配置
entry/src/main/ets/entryability/            # Ability 入口（窗口准备、加载 page）
entry/src/main/ets/entrybackupability/      # 应用数据备份/恢复
entry/src/main/ets/common/AppConfig.ets     # 服务器地址 / UserAgent / IMMERSIVE 开关
entry/src/main/ets/pages/Index.ets          # ArkWeb 壳页面（下拉刷新、返回、下载、权限、沉浸式补偿）
entry/src/main/resources/base/media/        # 启动图标等资源
entry/src/test/                             # 本地单元测试
entry/src/ohosTest/                         # 设备端测试
hvigorfile.ts / hvigor/                     # 构建配置
```

修改服务器地址：`entry/src/main/ets/common/AppConfig.ets` 的 `SERVER_URL` 与 `SERVER_HOST`。

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
