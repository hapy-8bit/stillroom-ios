# 播放页性能接续

本轮处理播放主页面卡顿，保留六款磁带和已有卷轴几何／切歌逻辑。证据目录沿用任务开始日期 `Evidence/0.4.0/cassette-performance-20261107`，实际采样发生在北京时间 2026-11-08。

## 定位与修改

同一台 USB iPhone 15 / iOS 26.6、相同轨迹屏与既有服务器曲目下，模塑和经典磁带的基线均约每 6 秒耗用 6.4 秒进程 CPU 时间。正确附加 App PID 的 Instruments 栈采样中，`LivePhotoRenderer.trails` 约占 88% CPU 样本；主线程权重约 10,102 ms。`Canvas(rendersAsynchronously: true)` 没有让这段逐像素计算离开主线程。仅凭磁带的新样式推断原因会遗漏这个主要瓶颈。

`OneTapeLivePhotoRasterizer` 把固定路径的距离衰减、时延、原始 RGB 预计算为稀疏发光像素表。每帧只更新这些像素的增益，移除重复的全图扫描、指数计算和密集数组访问；保留原来的路径、平滑函数、时间和颜色公式。缓存仍有数量上限。

`OneTapePhotoFrameStore` 在串行后台队列准备和绘制 Rain／Trails 帧，最多一份执行中请求和一份最新待处理请求。播放、暂停、换图尺寸／样式、相位重置和离页通过代际校验丢弃过期结果，延迟超过 150 ms 的旧运行帧也不发表。不修改媒体时间，不访问音频服务。CGImage 不可变结果回到主线程发布；离页没有持续生产循环。

实际播放由 `OneTapeApprovedAmbientDisplay` 显式启用后台帧。离屏静态绘制和设计预览保留同一算法的同步入口，使用独立缓存，避免预览等待播放后台任务的首次路径准备。首次画面准备期间显示对应原始照片，文本和输入继续响应。Rain／Trails 仍沿用原有视觉相位，其他电子屏未迁移此栅格通路。

`OneTapeReelMotion` 从 30 Hz 改为 60 Hz 调度，保持独立转角积分、暂停／后台／减少动效停止策略。显示调度值本身不能证明实际 FPS。

## 真机实测

使用正常签名 Debug build60 和 build61，UI 流程固定为岩层＋轨迹屏、相同既有两曲服务器队列，预热后 3 次约 6 秒 CPU／内存测量。两轮均在稳态标记后通过实际 App PID 附加同一 Instruments 模板，采样显示表面每秒呈现次数，排除首尾不完整秒。

| 指标 | build60 | build61 |
| --- | ---: | ---: |
| 稳态平均呈现率 | 17.2 /秒 | 59.6 /秒 |
| 约 6 秒 CPU 时间均值 | 6.453 秒 | 2.874 秒 |
| 进程物理内存均值 | 135,491 kB | 115,732 kB |

CPU 时间下降约 55.5%，物理内存下降约 14.6%。独立经典＋轨迹对照的 CPU 均值由 6.472 降至 2.726 秒。最终显示采样整秒为 58–61 次／秒；整数秒边界会出现 61，不表示设备刷新率超过 60 Hz。具体样本和计算口径在 `performance-comparison.json`。这些是本设备短时结果，不泛化为每款屏幕／设备／方向和长时热状态。

正常偏好的经典磁带＋干邑机身＋电平屏另外测得平均 58.7 次／秒，完整秒为 55–60；该流程没有选择或覆盖正常外观，结束后暂停并普通启动。构建后共享工作区的版本计数和部分自定义缩略图文件发生变化；性能相关 Swift 文件保持与实测 normal61 一致，后续共享变化单列在收据的 `source-drift.json`，未纳入本轮冻结产物验收。

XCTest 的 hitch 指标在慢基线也为零，不能据此宣布帧率通过。最早一次按进程名前缀附加时命中了 UI 测试运行器，该 trace 排除；正式对比使用完整可执行路径解析出的 App PID。额外正常外观采样曾遇到 CoreDevice socket EOF，记录为测试连接失败，不当作 App 性能结果。

## 验证与复测

23 项针对性检查覆盖稀疏绘制、现有屏幕／字体／方向、六款壳面、卷轴相位，以及后台执行、最新帧合并、暂停失效和取消后重建。手机分别复走模塑和经典的持续播放、暂停图像冻结；正常无参数外观也单独检查。真机当前正常偏好可由用户继续切换，不用测试预设覆盖它。

`OneTapeCassettePerformanceUITests` 使用同一计时工作量。实际安装必须由 `Tools/run-iphone-ui-check.cjs` 串行执行，UITargetAppPath 与依赖中同包名 App 必须为同一个正常产物；该工具在成功或失败后普通启动 App。正常外观附加采样使用 Xcode 文档支持的 `TEST_RUNNER_ONE_TAPE_PROFILE_NORMAL=1`，避免把测试运行器环境与目标 App 环境混淆。

采样时按 `CASSETTE_PERF_READY` 或 `CASSETTE_NORMAL_PERF_READY` 等待真实播放稳定，随后解析当前进程完整路径，不能按 `Stillroom` 前缀盲目附加。导出 `displayed-surfaces-per-second` 和 `time-profile`，更新比较文件后运行 `node Tools/check-player-performance.cjs <performance-comparison.json>`：呈现率至少 55 FPS、同工作量 CPU 降低至少 30%、物理内存不得增长超过 10%。

构建、安装和最终验收详见 [本轮凭据](../Evidence/0.4.0/cassette-performance-20261107/BUILD_RECEIPT.json)。没有卸载或清数据，没有复制用户音频；所比较的 Navidrome 索引字节哈希不变。播放测试会更新续听位置和诊断日志，不能称所有偏好字节不变。长时能耗和完整辅助功能／设备矩阵仍未验收。
