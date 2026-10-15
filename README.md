# travel-memory_harmony

Travel Memory（https://github.com/shihezichen/travel-memory）的鸿蒙 HarmonyOS 客户端壳应用。

应用已自托管在云主机上，通过 **ArkWeb (Web 组件)** 加载 `https://top001.xin`，
把现有 webserver 直接变成一个鸿蒙 App（路线：远程服务 + 本地 Web 壳）。

## 功能

- 全屏 ArkWeb 加载 https://top001.xin
- 加载进度条 / 连接失败错误页 + 一键重试
- `INTERNET` 权限、JavaScript 与 DOM Storage 已开启
- Stage 模型，API 12 (5.0.0)

## 构建

1. 用 DevEco Studio 打开本项目（需安装 HarmonyOS SDK，API 12+）。
2. File > Project Structure > Signing Configs 配置签名（自用可选自动签名）。
3. 连接鸿蒙设备/模拟器，Run。

命令行：`hvigorw assembleHap`

## 结构

```
AppScope/app.json5                    # 应用级配置 bundleName: xin.top001.travelmemory
entry/src/main/ets/pages/Index.ets    # ArkWeb 壳页面（服务器地址在此修改）
entry/src/main/ets/entryability/      # Ability 入口
entry/src/main/module.json5           # 权限 / Ability 配置
```

## 后续可扩展

- 下拉刷新、系统状态栏沉浸
- 外链跳系统浏览器（onLoadIntercept）
- 照片上传对接系统相册（ArkWeb 的 `<input type=file>` 已可触发系统选择器）
- 推送/桌面快捷方式

## License

MIT（与上游项目一致）
