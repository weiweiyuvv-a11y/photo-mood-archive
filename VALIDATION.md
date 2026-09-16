# 0.2.1 验证记录

2026-09-17，Xcode 26.4.1（17E202），iOS 26.4 / iPhone 17 Pro 独立测试模拟器，只使用样例图片。

## UI 恢复核对

对照 `prototype-v0.1` 恢复 ContentView、CalendarMonthView、DayDetailView、MoodDoodleView 的原视图结构、字号、间距、色彩、圆形照片缩略图、月份条与 Timeline / Trail 底栏。原设计色值已恢复。

与原 UI 源码相比，只增加了不可见的测试标识，以及必要的数据连接：权限按钮的设置跳转、语音文字追加、录音生命周期、图库删除后的可见照片同步、可取消的图片请求。加载提示文字随“跳过截屏”的实际数据规则校正，未新增页面或控件。

模拟器截图已人工查看；当前 README 截图为恢复后的界面，不再使用 0.2.0 截图。

## 已通过

- 模拟器 Debug / build-for-testing。
- iOS arm64 Release 构建（禁用签名）。
- 6 项 XCTest，0 失败、0 跳过：日期边界、过滤、旧版记录读写、空记录与心情边界、真实 PhotoKit 收藏和拍摄日期修改后刷新。
- 2 项 XCUITest，0 失败：原 Timeline / Trail 界面及原看图页收藏；原笔记编辑器保存、终止 App、重启后读回。
- `git diff --check` 通过。

最终结果包为本地 work/OriginalUIDataVerified.xcresult 与 work/OriginalUIVerified.xcresult。首次测试因测试模拟器权限被重置而缺少照片；通过真实系统授权后重跑，以上最终结果均通过。测试相册、日志、构建产物不上传 GitHub。

## 实机边界

未安装用户真机。iCloud-only 照片、有限相册授权、语音本地识别和大规模图库仍需真机验证。未对原 UI 再做视觉优化、平板重排或新增交互。
