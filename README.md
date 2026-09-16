# Photo Mood Archive

原生 iOS 照片日历与心情记录 App，SwiftUI + PhotoKit，iOS 17+，无第三方运行依赖。

## 当前版本：0.2.1

**界面已恢复为 `prototype-v0.1` 的原始设计。** 保留原来的月份条、圆形照片日历、Timeline / Trail 半透明切换栏、每日详情与心情面板。0.2.0 的三标签页、方块月历、手账搜索页及新配色已经撤回。

只保留下列数据与稳定性修复：

- 相册在后台扫描日期与位置元数据；图库变化后完整刷新，修复只检查最近 40 张造成的旧照片修改遗漏。
- 进入前台重新核对权限，撤销权限后清空内存照片索引；原权限按钮在被拒绝时打开系统设置。
- 排除截屏，不再因 180ms EXIF 超时或 iCloud 原文件不在本地而漏掉普通照片。不会为索引逐张下载原图。
- 图片请求有内存缓存和取消处理，图库更新后重新取图，避免复用过期缩略图。
- 收藏和删除使用明确的并发边界，避免 Swift 6 后台回调崩溃；同一照片的写操作防止重复执行。
- 照片在系统图库被移除时同步更新原有看图页面。
- 保留旧版三个 v1 存储键；空白笔记清理、心情值边界校验；覆盖安装可以继续读取旧记录。
- 语音识别接在已有笔记后面，避免覆盖原文字；退出编辑或进入后台时停止录音。中文本地识别不支持的设备仍可直接输入。

<img src="docs/screenshots/calendar.png" width="290" alt="恢复后的原版圆形照片日历，使用测试图片" />

## 运行

打开 `PhotoMoodArchive.xcodeproj`，选择 `PhotoMoodArchive` scheme 和 iPhone 模拟器。真机安装时选择自己的签名团队，保持原包名 `com.yuweiwei.photomoodarchive` 并覆盖安装，不要先卸载旧 App。

```sh
xcodebuild -project PhotoMoodArchive.xcodeproj -scheme PhotoMoodArchive \
  -sdk iphonesimulator -derivedDataPath work/Build CODE_SIGNING_ALLOWED=NO build
```

## 验证

`ArchiveTests` 检查日期、过滤、旧数据读写、空记录处理、真实 PhotoKit 收藏和拍摄日期更新。`ArchiveUITests` 检查恢复后的原界面、原笔记编辑器的重启持久化和原看图页的收藏操作。

在只含测试图片的模拟器上授权完整相册访问，导入至少一张当天测试图片，再执行：

```sh
xcodebuild -project PhotoMoodArchive.xcodeproj -scheme PhotoMoodArchive \
  -destination 'platform=iOS Simulator,id=SIMULATOR_ID' \
  -derivedDataPath work/Build -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

PhotoKit 集成测试仅在模拟器运行，会创建测试图片并更改它的日期及收藏状态；未授权时明确跳过。测试不应运行在个人真实图库中。

## 数据说明

照片直接读取系统图库；心情、笔记和歌曲在本机 UserDefaults 中，没有跨设备同步。卸载 App 会删除本地手账。预览 iCloud 照片和 Apple 地图可能使用网络；语音只允许设备本地识别。视频不在当前照片日历范围内。

`prototype-v0.1` 为原始代码；`v0.2.0` 为已撤回的界面重写版；`v0.2.1` 恢复原 UI、保留数据修复。验证范围见 [VALIDATION.md](VALIDATION.md)。
