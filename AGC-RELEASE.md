# 上架 / 分发给其他鸿蒙手机（AppGallery Connect）

这份文档是**给账号持有人（你）跟着做**的操作清单。工程侧我已经准备好，
真正只有一步代替不了：**用你的华为开发者账号在 AGC 申请发布证书 + 发布 Profile**。

---

## 0. 先分清两种包

| | 调试包（仓库现在的默认） | 发布包 |
| --- | --- | --- |
| 证书 | DevEco 自动生成的调试证书 | AGC 签发的发布证书 |
| 能装在哪 | **只有证书里登记过 UDID 的设备** | 任何鸿蒙设备 |
| 用途 | 自己开发调试 | 上架 / 分发给别人 |

现在 `build-profile.json5` 里配的是**调试**签名，所以打出来的
`*.app` / `*.hap` 只有你手上那台 Mate 60 RS 能装。要让别人装，按下面走。

> 顺带再确认一次：**鸿蒙装不了 APK**。APK 是 Android 的格式，
> 覆盖 Android 手机请用 [travel-memory_android](https://github.com/shihezichen/travel-memory_android)（那边已可直接下载）。

---

## 1. 前置准备

1. **华为开发者账号**：<https://developer.huawei.com/consumer/cn/> 注册并完成**实名认证**
   （个人可，需要身份证；企业要营业执照）。
2. 准备上架素材（审核要用）：
   - 应用图标：仓库里已有（`AppScope/resources/base/media/`），AGC 会再要一张 216×216 或 1024×1024；
   - 应用截图：3~5 张真机截图（手机截图就行）；
   - 一句话简介 + 详细描述；
   - **隐私政策 URL**：必须是一个可公开访问的页面，说明收集了哪些数据、怎么用。
     本项目数据完全自托管、不外传，这条在政策里写清楚即可。
     （若你还没有，可以先在站点上加一个 `/privacy` 页面。）

---

## 2. 在 AGC 建应用

AppGallery Connect → **我的项目** → 新建项目 → 项目里 **添加应用**：

| 字段 | 填什么 |
| --- | --- |
| 平台 | HarmonyOS |
| 应用包名 | `xin.top001.travelmemory` ← **必须和 `AppScope/app.json5` 的 `bundleName` 一字不差** |
| 应用名称 | 旅行记忆 |
| 应用分类 | 旅游 / 生活（按实际选） |

---

## 3. 生成密钥并申请发布证书 / Profile

### 3.1 本地生成密钥库（只需一次，之后要**永久保存**）

```bash
# 用 DevEco 自带的 JBR 即可
"<DevEco>/jbr/bin/keytool.exe" -genkeypair \
  -alias travelmemory-release \
  -keystore release.p12 -storetype PKCS12 -validity 10950 \
  -keyalg RSA -keysize 2048 \
  -dname "CN=Travel Memory, O=shihezichen, C=CN" \
  -storepass <你自己的口令> -keypass <你自己的口令>

# 生成证书请求文件（.csr），把它的内容贴到 AGC
"<DevEco>/jbr/bin/keytool.exe" -certreq \
  -alias travelmemory-release \
  -keystore release.p12 -storepass <你自己的口令> \
  -file release.csr
```

> ⚠️ `release.p12` 和口令**丢了就再也发不了同一应用的更新**（只能换包名重来）。
> 备份到密码管理器 / 离线介质里，别只放这台电脑。

### 3.2 在 AGC 申请

AGC → **证书、App ID 和 Profile**：

1. **证书管理 → 新增证书**：把 `release.csr` 的内容贴进去 → 下载 `.cer`。
   页面同时会给一个「**证书链**」文件 —— **后面配工程时要用证书链那个**，
   用单个 `.cer` 真机校验会失败。
2. **Profile 管理 → 新增 Profile**：
   - 类型：**发布**
   - 绑定：上面那张证书 + 包名 `xin.top001.travelmemory`
   - 下载 `.p7b`

（如果只是想给几个朋友用、不上架：Profile 类型选**调试**并把这些设备加进「设备管理」，
或者用「**受限分发**」/「内部测试」渠道。逻辑一样，只是前面第 6 步换成分发而不是提交审核。）

---

## 4. 配置工程（这一步我可以帮你改，把三个文件路径发我即可）

把 `build-profile.json5` 里的 `signingConfigs` 整段换成：

```json5
"signingConfigs": [
  {
    "name": "release",
    "type": "HarmonyOS",
    "material": {
      // AGC 下载的「证书链」，不是单证书
      "certpath": "C:\\keys\\release-chain.cer",
      // 3.1 生成的密钥库
      "storeFile": "C:\\keys\\release.p12",
      "storePassword": "<口令>",
      "keyAlias": "travelmemory-release",
      "keyPassword": "<口令>",
      "signAlg": "SHA256withECDSA",
      "profile": "C:\\keys\\release.p7b"
    }
  }
]
```

同时把 `app.products[0]` 里的

```json5
"signingConfig": "default",     // 改成
"signingConfig": "release",
```

**口令写法**：DevEco 的自动签名会把口令加密成 `0000001A...` 这种串。
最省事的做法是在 DevEco 里 `File → Project Structure → Signing Configs`
手动填一次 release 证书，IDE 会帮你加密写进去；直接写明文 hvigor 也认，
但**别把带口令的 `build-profile.json5` 提交到仓库**（本仓库的 `signingConfigs` 一直是空的）。

---

## 5. 打包

```bash
export DEVECO_SDK_HOME="<DevEco>/sdk"
export JAVA_HOME="<DevEco>/jbr"
export PATH="$JAVA_HOME/bin:$PATH"

"<DevEco>/tools/hvigor/bin/hvigorw.bat" assembleApp --no-daemon -p buildMode=release
```

产物：`build/outputs/default/travel-memory_harmony-default-signed.app`

验证签名对不对（换成真机装一次最直接）：

```bash
"<DevEco>/sdk/default/openharmony/toolchains/hdc.exe" list targets
"<DevEco>/sdk/default/openharmony/toolchains/hdc.exe" install -r entry/build/default/outputs/default/entry-default-signed.hap
```

> 用发布签名打出来的 `.hap`，装到**任何**鸿蒙设备上都应该成功；
> 如果还是只有你自己那台能装，说明用的还是调试证书。

---

## 6. 提交审核

AGC → 我的应用 → **版本管理** → 上传 `.app`：

- **版本号**：填 `AppScope/app.json5` 里的 `versionName`（当前 `1.0.0`）；
  注意 `versionCode`（当前 `1000000`）**每次发版必须递增**，否则上传会被拒。
- **更新说明**：写这次改了什么。
- **应用信息**：分类、标签、截图、简介、**隐私政策 URL**。
- **权限用途说明**：逐条填。本项目只申了这些，用途可以直接抄
  `entry/src/main/resources/base/element/string.json` 里的文案：

  | 权限 | 用途 |
  | --- | --- |
  | `ohos.permission.INTERNET` | 加载远程网页与媒体 |
  | `ohos.permission.GET_NETWORK_INFO` | 网络状态检测 |
  | `ohos.permission.APPROXIMATELY_LOCATION` / `ohos.permission.LOCATION` | 用于在地图和轨迹中定位你当前的位置，记录旅行足迹 |
  | `ohos.permission.CAMERA` | 用于拍摄照片并上传到你的旅行记忆 |
  | `ohos.permission.MICROPHONE` | 用于录制或上传带声音的视频 |

- 提交后等审核（一般 1~3 个工作日）。

---

## 7. 常见卡点

| 现象 | 原因 |
| --- | --- |
| 上传 `.app` 时报「包名不匹配」 | AGC 建的包名和 `AppScope/app.json5` 的 `bundleName` 不一致 |
| 上传时报「版本号已存在」 | `versionCode` 没递增 |
| 别人装了闪退 / 装不上 | 用的还是调试证书（绑了 UDID） |
| 真机提示签名校验失败 | `certpath` 用了单证书，应该用 AGC 给的**证书链** |
| 审核被打回 | 隐私政策缺失、或权限用途没填、或截图不符合要求 |
| 想先小范围试 | 用「受限分发」或内部测试渠道，不用等审核 |

---

## 8. 我可以帮你的部分

把这三样发我，我直接把配置改好、打出版本包并做一次安装验证：

1. `release-chain.cer`（证书链）
2. `release.p7b`（发布 Profile）
3. `release.p12` 及其口令

（敏感材料你也可以自己填，我只负责改 `build-profile.json5` 的路径和别名，
以及跑 `assembleApp -p buildMode=release` 并核对产物。）
