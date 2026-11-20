# One Tape 工作交接与 USB iPhone 接续

交接日期：2026-11-07，Asia/Shanghai。来自聊天「One Tape 曲库与播放接续」`01a1b3b8-2c5a-7422-a7b1-86087a16dd31`。

本文是本聊天交接时的最新入口。工作区与其他聊天共享，接手必须重新核对正在进行的 build54，不能把本文的历史记录当作当前设备状态。

## 1. 用户最新要求

- 本项目后续的新聊天、构建交付默认使用 **USB 连接的 iPhone 真机**：正常签名构建、保留数据覆盖安装、启动并核对本次影响的页面；用户已经授权，不要再次询问是否允许安装。
- 已写入项目根 `AGENTS.md`。隔离模拟器仍可辅助运行必要的 XCTest，但不能代替真机交付，也不能把构建/签名/安装成功当成真机视觉或音质验收。
- 拨杆、来源整页转场、录音机翻背方案已被用户明确叫停，先不做。预览文件只在聊天可视化目录，**从未接入 App**，不要恢复这个需求。
- 用户最后完成的产品需求：不同机身下左下三个按钮应有不同配色；播放中手动切歌时，两卷轴先短暂快转、停顿，再播放目标歌曲。

## 2. 工程身份与共享状态

工作目录：`/Users/liuhang/Documents/Google_Project/stillroom-ios`。这是独立 iOS 工程，不改动/同步/发布 HarmonyOS 或网页工程。

- 产品名 One Tape；project/target/scheme/module 为 Stillroom。
- Bundle ID `com.liuhang.stillroom`；配置 `Config/App.xcconfig`。
- 交接核对时版本 **0.4.0 / build54**。不能回退到 build53，也不能单凭根收据判断最新版本。
- Git 大部分文件仍未跟踪，不能因为 `git diff` 为空就判断没有修改；不得 reset/clean，不提交整个目录，不覆盖其他聊天未提交的工作。
- 签名团队只在被忽略的 `Config/Signing.local.xcconfig`。沿用原签名身份，不复制密码/证书到文档，不卸载或清数据。
- 手写源码最多 800 物理行；PlayerStore 现约 641 行，已经按职责将新切歌状态机放在独立 Controller；继续扩展应拆分职责，不能压行。

当前同目录活动聊天（只读核对它们的状态，不盲目并行修改相同文件）：

| 聊天 | ID | 交接时状态 |
| --- | --- | --- |
| 确认印花与屏幕效果可见性 | `01a1b36e-e377-7db0-9c5e-da2e7f8867eb` | 正在收尾 build54 的屏幕字体、计时、符号和横向内部布局；UI journey 仍在更新 |
| 设计磁带样式并调整主标题字体 | `01a1b62d-d240-7c51-94b2-fe6524b03d24` | 活动状态，先读取最新任务范围，避免重绘/覆盖其稿件 |

## 3. 必须区分的三个基线

### 本聊天已实际交付：build53

- 产物：`Build/TransportFinish53/Build/Products/Debug-iphonesimulator/Stillroom.app`。
- 完整、成功的结果包：`Build/TransportFinish53/refinement-first.xcresult`。
- **56 项通过、0 失败/跳过**：54 模型/真实引擎/渲染，2 模拟器 UI。源码检查 316 文件、最大 641 行，正常模拟器签名核验通过。
- 已保留数据安装到原预览 `77CFAADC-0D5D-4E5B-864A-B5019465A476`；实际看过自适应青色机身的三个按钮、播放、下一首后从 0 推进至 9 秒、暂停，再返回原第4首 Stories from Emona IV 的 0:00 暂停主页。
- 六份原曲库/唱片/封面文件 SHA256 未变，机身偏好未变。模拟器覆盖安装迁移了 data container UUID，路径不同不等于丢数据，不要写成“路径未变”。
- **本聊天未把 build53 安装到实体手机**。该版本的机械音色和切歌体验不能称真机验收。
- 完整证据：`Evidence/0.4.0/transport-material-windup-20261107/BUILD_RECEIPT.json`、`test-summary.json`、`delivery-final-check.json`、`simulator-update.json`、`original-final53.png`。

### 历史未交付的屏幕快照：不要误当成最新故障

build53 验证期间其他窗口在改屏幕。本聊天复制了固定源码快照 `Build/TransportFinish53Source` 做补充检查；复制时缺少新屏幕布局文件的工程登记，补登记后 Transport 用例及2条 UI 都通过，但当时的屏幕渲染类有5个用例失败（多条格式断言）。该快照 **未安装到原预览，不作为交付包**。

- 详情：`Evidence/0.4.0/transport-material-windup-20261107/later-screen-test-summary.json`、`snapshot-build-retry.json`、`xcode-final.log`。
- 日志记录 69 个通过用例、5 个失败用例；重复的 Transport 检查不能与前面56累计。
- SDK snapshot cleanup 出现 `invalidDigitCount` 后结果包没有完整收尾，本聊天终止了自己的补充 xcodebuild；不要声称 `Build/TransportFinish53Final/refinement-registered.xcresult` 是完整成功结果。
- **后续屏幕窗口已经继续修正并推进 build54，先读其最新凭据，不要照着旧5fail重新改当前代码。**

### 当前工作区：build54 正在由屏幕窗口收尾

先查看 `Evidence/0.4.0/screen-labels-orientation-20261107/`：

- `models-render-final.log` 已记录 **38 项通过、0 失败，TEST SUCCEEDED**；`models-render-final.xcresult` 已有 Info.plist。
- `ios-build.log` 已记录 `BUILD SUCCEEDED`；`artifact-versions.json` 记录 simulator 和 `deviceBuildOnly` 均为54。**deviceBuildOnly 只证明真机包构建，不证明安装/启动。**
- 交接核对时 `ui-journeys.log` / `ui-journeys.xcresult` 正在更新。接手重新读取该聊天的最终状态、收据及设备安装记录后再决定是否还有失败。
- 根 `BUILD_RECEIPT.json` 此刻仍属于 build52 屏幕交付；README 顶部仍是本聊天 build53。不要覆盖屏幕窗口正写的文档，待它收尾后合并索引。
- 本聊天旧 QA 的56项不能证明后续全部屏幕源码。build54 最终包还需针对性回归本聊天的按钮与短按绕带，尤其 PlayerFace 的状态注入不能丢失。

## 4. 本聊天完成的实现与源码入口

### 按机身的三键材质

- 可见圆键直径仍58逻辑点，中心/间隙/44点触摸区域保留。
- `Stillroom/Domain/OneTapeTransportMaterial.swift`：按 BodyStyle/BodyColor 选材质，原黑保持原照片；石墨、白/鸽灰、彩色使用协调材质。RGB 是本轮设计值，不是已恢复的原版完整颜色表。
- `Features/OneTape/Player/OneTapeTransportKeyVisual.swift`：底面、边缘、符号、旋转、播放灯统一绘制，防止浅色按钮又被黑色 PNG/补丁覆盖。
- `OneTapeBodySurface.swift` 只清除原旧圆区并渲染机身，按钮在 TransportKey 中绘制。
- `OneTapePlayerFace.swift` 给 Key 传 `appearance` 和 `transportAction`，原外层黑色转向补丁已删除。
- 回归：`OneTapeTransportMaterialTests`（7项）、`OneTapeTransportGeometryTests`（3项），含原黑像素、浅色/彩色、方向、灯面及整机黑边裁切。

### 播放中短按切歌先绕带

- `State/OneTapeTrackWindupController.swift`：可取消的 650ms ±14倍视觉绕带 → 140ms 0倍刹停 → 校验 trackID + selectionRevision 后调用同一权威引擎恢复。
- 原版静态线索确认短按14倍/0.65秒、长按±6倍；140ms停顿是体验参数，未称原版精确间隔。参考边界在本轮 `reference-boundaries.json`。
- `PlayerStore.swift` 发布 `tapeTrackMotionRate: Double?`；nil=普通播放率，0=停转，±14=短按快转。`isTapeTrackChanging` 表示待恢复机械阶段，不伪造媒体 playing/preparing。
- `PlayerStore+OneTapeTransport.swift` 协调短按、暂停、原队列和长按。视觉相位不作真实媒体 seek；长按仍沿用独立±6倍 seek。
- `OneTapeMusicStore.stepTrackForTape` 发出短按；pending时点播放键只取消/暂停，不能把已经暂停的实际 engine 误当作新 Play；音效仍只响一次机械切歌声。
- `OneTapeRoot → OneTapePlayerFace.trackChangeMotionRate` 必须保留。播放键 pending 期间仍表示“暂停/取消”，AX 为“切歌快转/切歌停顿”；LCD 显示实际媒体状态。
- 连续点击只恢复最终选择；暂停、外部选曲/暂停、后台、错误、长按应取消旧任务；暂停态短按不自动开始播放。
- 回归：`OneTapeTrackWindupTests` 8项、`OneTapeTrackWindupIntegrationTests` 7项、原 Feedback 9项、Transport 13项、CuePolicy 7项、`OneTapeTransportRefinementUITests` 2项。

## 5. 其他已完成内容，不要重新标为未实现

- 本地封面：读音乐内嵌图、同目录 cover/folder 整专辑建议、首曲无图时后续曲目回退、手动补整张专辑封面、缓存刷新、损坏图片提示。音乐文件字节不改。
- 设置：隐私政策、用户服务、付费说明、联系我们、反馈。邮箱 **hapy8bit@163.com**，**人民币9.90一次性买断、不自动续费**。当前未开放真实购买，无 StoreKit 实际交易/验证/恢复；不要伪造成功或承诺所有未来功能。
- 本地音乐 + Navidrome 为产品范围；不要另接 Apple Music。已有断开连接、远端统计、收藏/取消、真实最近添加/播放排序、常亮持久化及凭证清理路径。
- 三圆键58点/10点可见间隙、机身磁带矩形黑边裁切、顶部 HUD 纯淡入淡出已经落地。
- 播放/暂停与切歌音效使用独立 CC0 磁带机实录加工，原始片段/许可/来源在 `Tools/AudioSources/Transport` 与包内 `PROVENANCE.json`。没有复制原版 App 音频；播放器仍只有一个 AVPlayer。
- 本聊天未实现 B 面 transport/翻面。屏幕窗口 build54 正在接 A/B 队列显示，需区分“屏幕标记”与“整套物理翻面播放”，不要把旧固定A结论覆盖到当前源码。

## 6. 设备与后续执行顺序

交接时只读核对了 USB 设备：

- 名称 iPhone，型号 iPhone 15（iPhone15,4），iOS26.6。
- 历史可用 UDID：`00008120-000E4DE11ED2201E`。
- `xcrun devicectl device info details` 返回 `transportType: wired`、`pairingState: paired`、Developer Mode enabled。**执行时重新发现设备，不盲目复用旧ID。**
- build52 曾在此 iPhone 安装并空库检查；build54 的真机安装在交接时未确认。没有足够证据声称手机已有音乐或音质已验收。

建议新聊天直接接续：

1. 读本文、根 AGENTS、当前配置及屏幕窗口最新收据/状态。它仍在写文件时，先做只读核对、设备准备和回归计划，不抢同一页面或版本号。
2. 接收 build54 最终源码/测试结论。历史5fail若已被新38项最终结果覆盖，不重复修；仍有真实缺陷再定位修复，不能仅放松断言。
3. 在整合后的确定源码上跑 `node Tools/check-source.cjs`、实际 Xcode 构建和必要的 Transport/屏幕针对性 XCTest。固定源与产物哈希，避免又在测试过程中换源码。
4. **对当前USB iPhone签名构建、保留数据覆盖安装、正常启动。** 沿用 scheme Stillroom、bundle com.liuhang.stillroom 和本地签名配置。没有必要不要重新生成整个 project/target identity。
5. 真机核对按钮在黑/石墨/浅色/彩色下的正常和播放状态、前后曲、快转/停顿/新曲起播、连续切换与暂停取消；保留现有用户数据和偏好。若需测试音乐，仅用已授权合成测试素材，不自动导入私人音乐；把空库验收与实播验收分开记录。
6. 补当前设备能完成的锁屏/控制中心、离前台取消和恢复、实际音效主观试听；蓝牙/耳机/中断等需要真实可用路由时再测试，未验证如实列出。
7. 更新本轮 README/BUILD_RECEIPT/独立 Evidence，分别写清源码版本、签名构建、安装、实际查看/实播及尚未验证项。不要将旧阶段/重复测试累计。

暂缓范围：来源拨杆/背面新页、完整B面/物理翻面、小组件实际 WidgetKit、iPad遥控器、Apple Music SDK、未授权真实付款、商店发布；沙丘/铁屑/墨水/水面新设计及其他美术稿按对应窗口与用户范围处理，不自动扩展。

## 7. 模拟器仅作辅助的识别线索

- 本聊天独立 QA：`145AB0F0-7904-472C-9A3E-D78A78D5440B`，One Tape Detail QA46，已有合成 Cover QA 两曲专辑；UI用例有这个UUID保护，不要强行绕过保护跑到真机/原预览。
- 原预览：`77CFAADC-0D5D-4E5B-864A-B5019465A476`。交接查询时为 shutdown；最后本聊天交付53，不保证之后无人更新。
- 屏幕窗口 QA：`2C650379-F02A-4D67-9C0A-3DAC0390EBAB`，One Tape Print Redraw QA。不要操作/终止它的进程或写它的曲库。

较早交接 `Docs/ONE_TAPE_HANDOFF_2026-11-07.md` 含大量已完成的历史 P1 清单和旧 build42 基线，只用于追溯；本文件与接手时的最新源码/独立收据优先。
