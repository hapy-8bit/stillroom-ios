# One Tape · iOS

源码仓库：[hapy-8bit/stillroom-ios](https://github.com/hapy-8bit/stillroom-ios)。

2026-11-20 起，默认完成改动后检查源码、提交并推送 GitHub。只有明确要求构建、安装或运行验收时才生成本地构建产物；此时仍使用指定的 Stillroom iPhone 16 Pro 模拟器并保留数据。签名配置、安装包、缓存、设备诊断和历史录屏只保存在本机，不进入公开仓库。

下方是既有版本的历史记录，其中的构建与安装流程不作为后续任务的默认要求。记录中引用的 Evidence、Artifacts、分析与生成目录为本机资料，未随公开源码上传。

## 2026-11-11 / build99 「你的绘画与照片」1:1 界面与流程对齐版

对照 `CassettePrintAnalysis/01-你的绘画与照片/` 实机镜像截图（`01-print-block.png`～`05-studio-paywall.png`）、逆向报告与本地化词库，在本仓库完成「你的绘画与照片」模块细节对齐与重制（不改动鸿蒙与网页工程）：

- **入口区块与缩略图（[`OneTapePrintCustomization.swift`](Stillroom/Features/OneTape/Customization/OneTapePrintCustomization.swift)）**：新增自定义矢量路径图标 `OneTapePencilSquiggleIcon`（铅笔与波浪线）与 `OneTapeHalftoneIcon`（渐变网点簇圆环）；为已保存的「画作」与「照片」卡片补全横向磁带镂空剪裁纸面底托（`cassetteMaskedTileThumbnail`），使其与内置涂鸦缩略图视觉一致，并调整「获取画纸」「导入」胶囊按钮的右上橙色标注点布局（保留预览可用性，未在模拟器上强制拦截）。
- **「画画」画纸画布（[`OneTapeDrawingCanvasView.swift`](Stillroom/Features/OneTape/Customization/OneTapeDrawingCanvasView.swift)、[`OneTapeDrawingWorkflowModifier.swift`](Stillroom/Features/OneTape/Customization/OneTapeDrawingWorkflowModifier.swift)）**：将 3D 磁带图底换为原版 `#D0D9E9` 浅蓝画纸卡片 + `#FAF7F1` 米白磁带可画区域 + `#8AA2C9`/`#9AABD1` 细描边轮廓；顶部改为极简白字「取消」、居中撤销/重做、「完成」在未落笔前灰显禁用（`_hasInk` 激活）；修复深色模式下 `PKCanvasView` 自动反白画笔的问题（强制画布 `.light` 笔色样式，笔迹改为锐利深黑且自动识别单色/彩色模式）；`PKToolPicker` 预置 5 项常用笔具并开启 `stateAutosaveName`。
- **「网点 / 新照片印花」空态与控制面板（[`OneTapeHalftoneWorkflowModifier.swift`](Stillroom/Features/OneTape/Customization/OneTapeHalftoneWorkflowModifier.swift)、[`OneTapeHalftoneEditorView.swift`](Stillroom/Features/OneTape/Customization/OneTapeHalftoneEditorView.swift)、[`OneTapeHalftoneControls.swift`](Stillroom/Features/OneTape/Customization/OneTapeHalftoneControls.swift)、[`OneTapeCustomArtwork.swift`](Stillroom/Domain/OneTapeCustomArtwork.swift)、[`OneTapeHalftoneEngine.swift`](Stillroom/Services/OneTapeHalftoneEngine.swift)、[`OneTapeArtworkCropSheet.swift`](Stillroom/Features/OneTape/Customization/OneTapeArtworkCropSheet.swift)）**：点击「网点」先以 `.sheet` 弹出「新照片印花」空态引导页（「让这盘磁带成为你的专属。」＋「选择图片」＋「保存在这台 iPhone 上…」），「应用」未选图前禁用；上部预览改用横版磁带并修正照片 `+90°` 合成方向使其正向适配；载入后显示「更换图片」「裁剪」胶囊、两级分段控件（「网点照片｜涂鸦」「复古｜植物｜叠印」）、内联「仅保留主体」开关、奶油色填充胶囊滑块 `OneTapeHalftoneCapsuleSlider`（默认 `52%` / `45%`）与「墨水」色板；裁剪页补充顶部说明「留下你想印出的部分。」。
- **验证结果（隔离 QA 与预览器）**：`Stillroom.app` (`0.4.0 build 99`, `Assets.car = 77M`) 已保留原数据覆盖安装并启动于 `Stillroom iPhone 16 Pro`（`77CFAADC-0D5D-4E5B-864A-B5019465A476`，`PID 54385`，`sim_preview_99_final.png` 核验）；`One Tape Mould QA`（`E96BF9E8-0E11-45E9-9CBA-2546DF0A32FA`）定向通过 4 个单元测试集共 **26/26** 项（`OneTapeAppearanceTests` 8/8、`OneTapeCustomDrawingTests` 3/3、`OneTapeHalftoneArtworkTests` 3/3、`OneTapeMouldedRenderingTests` 12/12）与 [`OneTapeCustomPrintUITests`](StillroomUITests/OneTapeCustomPrintUITests.swift) **2/2** 项，实测检视 `01-print-section`、`02-drawing-canvas-empty`、`02-drawing-canvas`、`03-print-section-with-drawing`、`04-get-paper-share`、`06-halftone-empty` 与 `14-player-doodle-pelican-bicycle` 截图。
- **未验证与保留边界（如实记录）**：`新照片印花` 选图后的实时载入参数界面未通过系统 `PhotosPicker` 做 UI 自动化截屏验收（仅在单元测试验证排版旋转、标题与合成算法）；`PKToolPicker` 在 iOS 27 模拟器首次打开呈左下角收起圆钮（`stateAutosaveName` 持久化展开状态未做 UI 展开重截）；其余无关单元/UI 测试集（如 `OneTapeBronzeRenderingTests`、`OneTapePurchaseUITests`、`OneTapeSupportUITests`）未在 build 99 重跑，亦未做 USB 真机构建与验收。

## 2026-11-11 / build98 内置印花高清重绘优化与「鹈鹕骑自行车」预览版

本次仅修改当前独立 iOS 工程，不涉及鸿蒙与网页工程。

- **风格保持与边界**：严格遵循 One Tape 极简法式细线钢笔插画风格；按要求完整保留 **`城市`（`.city`）** 原版钢笔画与细节，并保留 **`野生`（`.wild`）** 与 **`小机器`（`.littleMachines`）**，其余 **77** 款内置印花升级为 `1536×1024 RGBA` 墨水遮罩与 `576×384` 网格缩略图。
- **Classic 主视觉 8 款重绘与「鹈鹕骑自行车」**：[`bicycle`](Stillroom/Domain/OneTapeDoodleCatalog.swift) 替换为同心双轴轮「鹈鹕骑自行车」极简线描，并重绘清理 [`climber`](Stillroom/Domain/OneTapeDoodleCatalog.swift)、[`smile`](Stillroom/Domain/OneTapeDoodleCatalog.swift)、[`cat`](Stillroom/Domain/OneTapeDoodleCatalog.swift)、[`fishing`](Stillroom/Domain/OneTapeDoodleCatalog.swift)、[`tightrope`](Stillroom/Domain/OneTapeDoodleCatalog.swift)、[`swing`](Stillroom/Domain/OneTapeDoodleCatalog.swift)、[`sleeper`](Stillroom/Domain/OneTapeDoodleCatalog.swift)，去除旧版缩放锯齿黑圈与边角缺口，同时仅在保留原有线条基础上为 `dog`、`caterpillar`、`seesaw` 补充轻量化钢笔伴随细节。
- **全幅底纹与 14 壳分壳高清重制**：对 9 款高频密线全幅纹样（`creatures`、`people`、`plants`、`daydream`、`faces`、`shapes`、`soundMaze`、`orbitDoodles`、`circuitGarden`）进行分阈值 SDF + Chaikin 平滑矢量化；对其余 57 款分壳插画按各壳体实测坐标绘制有机手绘扰动 `<svg>` 细线稿并高分栅格化；受 `generate_image` 配额（429 冷却）限制，仅前 8 款 Classic 主视觉采用 AI 生图，其余重构款采用本地矢量化/SVG 管线完成，已在下文未验收项如实标注。
- **渲染方向与工程配置适配**：更新 [`OneTapeDoodleCatalog.inkAsset(for:)`](Stillroom/Domain/OneTapeDoodleCatalog.swift) 使 74 款横版重构 `1536×1024` 资源默认 `isPortraitTemplate = false`（`.littleMachines` 保持 `true`），微调 [`OneTapePrintCustomization`](Stillroom/Features/OneTape/Customization/OneTapePrintCustomization.swift) 底部说明文案，[`OneTapeCustomPrintUITests`](StillroomUITests/OneTapeCustomPrintUITests.swift) 新增 `pelican-bicycle` 点击切换与 `"14-player-doodle-pelican-bicycle"` 截图断言，版本推进至 `0.4.0 (build 98)`（[`App.xcconfig`](Config/App.xcconfig)）。
- **验证与未验收范围（如实记录）**：`Assets.car` 实测 `77M`；隔离 QA 模拟器 `One Tape Mould QA`（`E96BF9E8-0E11-45E9-9CBA-2546DF0A32FA`）定向通过 [`OneTapeAppearanceTests`](StillroomTests/OneTapeAppearanceTests.swift)（8/8）、[`OneTapeMouldedRenderingTests`](StillroomTests/OneTapeMouldedRenderingTests.swift)（12/12）与 [`OneTapeCustomPrintUITests/testBuiltInDoodlesGridAll80ToggleAndCassetteRender`](StillroomUITests/OneTapeCustomPrintUITests.swift)（1/1，实测检视 `10-doodle-classic-grid`、`11-player-doodle-climber`、`14-player-doodle-pelican-bicycle`、`12-player-doodle-little-machines`、`13-doodle-all80-expanded` 5 张截图），并已保留数据安装启动到 `Stillroom iPhone 16 Pro`（`77CFAADC-0D5D-4E5B-864A-B5019465A476`，`PID 33543`，`sim_preview_98.png` 核验）。未实测其余 15 个磁带壳型的实时 UI 视觉效果，未重跑 `OneTapeBronzeRenderingTests` / `OneTapeCustomDrawingTests` / `OneTapeHalftoneArtworkTests` 及 `testDrawingCanvasImportDialogPaperShareAndPlayerRender`，亦未做真机 Release 构建与实机渲染验证。

## 2026-11-11 / build97 内置「印花（Doodles）」全量 80 款与分壳排序预览版

结合 DS 逆向报告（`CassettePrintAnalysis/report/REPORT.md`、`CassettePrintAnalysis/report/SUBPAGES.md`）与 Codex/Ghidra 二进制反编译定位（`TapeDoodle` `0x1009a78e8`、`1001e41f4`、`1001e1e1c`、`1001e0e88`、`1001e2ef8`、`1001e3bdc`），在「自定义 → 印花」落地内置全量 80 款印花预览与原版分壳展示规则：
- **全量 81 个枚举与官方中文命名**：在 [`OneTapeAppearance.swift`](Stillroom/Domain/OneTapeAppearance.swift) 将 `DoodleStyle` 扩充至全部 81 个枚举（`.none` + `climber..orbitDoodles` 18 款通用印花 + `dog..theatre` 62 款分壳印花，保留 `.wild` `rawValue = "wild"` 并兼容解码 `"overgrown"`），并在 [`OneTapeDoodleCatalog.swift`](Stillroom/Domain/OneTapeDoodleCatalog.swift)（已加入 `Stillroom.xcodeproj/project.pbxproj`）集中维护中文名称（按官方 `zh-Hans.lproj` 校正 `'Circuit board' -> '电路板'`、`'Orbits' -> '轨道'`、`'Machines' -> '小机器'` 等）与资源基名。
- **80 款缩略图与 `1024×1536 @3x` 透明线稿**：导入缺失的 75 组官方 `288×192 @3x` 缩略图（`OneTapeDoodle<Base>Thumb`）与原版内嵌全尺寸原图 `DoodleLittleMachines.png`（`OneTapeDoodleLittleMachinesInk`，`1024×1536 @3x` RGBA），保留既有 5 组 `RecreatedInkV1`，并对原版存放在 ODR（On-Demand Resources）远程包的其余 74 款从官方缩略图经模板差分与 Lanczos 放大提取纯黑透明线稿（`OneTapeDoodle<Base>Ink`）。
- **分壳筛选排序与「全部 80 款」切换**：[`OneTapeDoodleCatalog.swift`](Stillroom/Domain/OneTapeDoodleCatalog.swift) 的 `supportedStyles(for:)` 按原版 `[.none] -> 当前壳体专属 -> 通用 18 款` 顺序返回适配列表（`经典白色 / 黑色` 严格对齐原版 24 项顺序：`无`、`小狗`、`毛毛虫`、`跷跷板`、`城市`、`野生` + `攀岩者..轨道`；其余 14 款壳体匹配对应风格及避开模塑边距的全铺图案）；[`OneTapePrintCustomization.swift`](Stillroom/Features/OneTape/Customization/OneTapePrintCustomization.swift) 默认展示当前壳体适配印花，并在右上角提供 `全部 80 款` / `仅当前磁带` 切换胶囊（`customization.doodle.scopeToggle`）。
- **线稿合成与无障碍标题**：[`OneTapeDoodleArtwork.swift`](Stillroom/Features/OneTape/Player/OneTapeDoodleArtwork.swift) 支持竖版 `1024×1536` 线稿通过 `.renderingMode(.template)` 按浅色壳 `(0.10, 0.10, 0.11)` 与深色壳 `(0.93, 0.91, 0.87)` 墨色渲染，经 `OneTapeShellPrintMask` 遮罩与 `OneTapeDoodleClassicLight` 正片叠底合成；[`OneTapeCustomizationCatalog.swift`](Stillroom/Features/OneTape/Customization/OneTapeCustomizationCatalog.swift) 与 [`OneTapePlayerFace.swift`](Stillroom/Features/OneTape/Player/OneTapePlayerFace.swift) 统一读取 `customizationTitle`。

**源码检查通过（`402` 个维护源码文件、最大 `666` 行，无超限文件）；隔离 QA 模拟器 `One Tape Mould QA` 上运行 31 项单元测试全部通过（`OneTapeAppearanceTests` 8 项、`OneTapeBronzeRenderingTests` 5 项、`OneTapeCustomDrawingTests` 3 项、`OneTapeHalftoneArtworkTests` 3 项、`OneTapeMouldedRenderingTests` 12 项，0 失败；其中 `testTheSameIllustrationDoesNotChangeWhenSwitchingMoulds` 作用域收口至适配模塑边距的款式）及 UI 过滤用例 `OneTapeCustomPrintUITests/testBuiltInDoodlesGridAll80ToggleAndCassetteRender` 通过（核验经典网格、攀岩者、小机器、全部 80 款展开态 4 张截图）。** Debug 包（`0.4.0 / build 97`，`Assets.car` `79M`）已保留沙盒数据覆盖安装并启动到 `Stillroom iPhone 16 Pro`（`77CFAADC-0D5D-4E5B-864A-B5019465A476`，PID `43150`）。**未验证项**：其余 15 款磁带壳体的实际 UI 运行视觉效果、74 款重建线稿与原版 ODR 原图在放大细节上的一致性、`testDrawingCanvasImportDialogPaperShareAndPlayerRender` 未在本轮复测，且未做真机 Release 构建或真机实测。

---

## 2026-11-11 / build96 印花「你的绘画与照片」全功能复刻（绘画 / 画纸导入 / 网点照片）

参照原版二进制逆向结构与官方本地化文案，在「自定义 → 印花」完整实现 **你的绘画与照片** 两大能力，并通过统一底层遮罩与图层管道挂载到全部 16 款磁带壳体及播放器／小组件预览：
- **画画（PencilKit）**：[`OneTapeDrawingCanvasView.swift`](Stillroom/Features/OneTape/Customization/OneTapeDrawingCanvasView.swift) 提供 `PencilKit` 原生绘图工作室，内置当前磁带底图对照、镂空导引暗角及撤销／重做／清空；支持保存到 [`OneTapeDrawingStore.swift`](Stillroom/Services/OneTapeDrawingStore.swift)（生成 `画作 1/2…` 与独立损坏索引保护）、长按上下文菜单（`编辑` / `在上面画` / `切换墨色模式` / `删除`）。
- **获取画纸与导入**：[`OneTapeDrawingPaperService.swift`](Stillroom/Services/OneTapeDrawingPaperService.swift) 与 [`OneTapeDrawingPaperInkExtractor.swift`](Stillroom/Services/OneTapeDrawingPaperInkExtractor.swift) 生成带蓝色镂空区域与四角定位标识的 `2604 × 1836`（`150px` 边距）高清画纸 PNG，经系统分享面板导出（已在 `Info.plist` 补充 `NSPhotoLibraryAddUsageDescription`）；支持从「照片」或「文件」导入，通过透明通道直通、Vision 透视矫正及蓝色抠除／纸张色去污提取纯墨迹，并在 [`OneTapeDrawingReviewView.swift`](Stillroom/Features/OneTape/Customization/OneTapeDrawingReviewView.swift) 选择 `使用磁带墨色` / `保留原色`、`在上面画` 或 `留下它`。
- **网点照片与线稿（Halftone）**：[`OneTapeHalftoneEngine.swift`](Stillroom/Services/OneTapeHalftoneEngine.swift)、[`OneTapeArtworkStore.swift`](Stillroom/Services/OneTapeArtworkStore.swift)、[`OneTapeHalftoneEditorView.swift`](Stillroom/Features/OneTape/Customization/OneTapeHalftoneEditorView.swift) 与 [`OneTapeArtworkCropSheet.swift`](Stillroom/Features/OneTape/Customization/OneTapeArtworkCropSheet.swift) 实现网点（`单色` / `植物` / `叠印`）与纸张线稿（`墨水`）双模式，包含 Vision 前景抠图（`仅保留主体`）、拖动／双指缩放／旋转／裁剪定位、`网点大小`／`印迹磨损`（12 边形有机网点 + 正弦纸纹损耗）／`浓度`／`去杂` 滑块、7 种墨色选择（`磁带墨色` + 6 色板），以及列表中的 `照片 %lld`、`编辑`、`为这盘磁带重新印制` 与容量上限提示（最多 8 张）。
- **底层与隔离展示**：新增 `customDrawingID` 与 `customArtworkID` 至 [`OneTapeAppearance.swift`](Stillroom/Domain/OneTapeAppearance.swift)（与品牌印字及已有涂鸦严格互斥，保持旧配置向后兼容解码）；抽出共享 [`OneTapeShellPrintMask`](Stillroom/Features/OneTape/Player/OneTapeDoodleArtwork.swift#L101) 与 [`OneTapeCustomPrintLayer`](Stillroom/Features/OneTape/Player/OneTapeDoodleArtwork.swift#L123)，并通过独立交互修饰器 [`OneTapeDrawingWorkflowModifier.swift`](Stillroom/Features/OneTape/Customization/OneTapeDrawingWorkflowModifier.swift) 与 [`OneTapeHalftoneWorkflowModifier.swift`](Stillroom/Features/OneTape/Customization/OneTapeHalftoneWorkflowModifier.swift) 挂载到播放器主页与定制弹窗，避免视图节点与选择框冲突。

**源码检查通过（`401` 个维护源码文件、最大 `666` 行，无超限文件）；隔离 QA 模拟器 `One Tape Mould QA`（iOS 27.0）中 `OneTapeAppearanceTests`（7 项）、`OneTapeCustomDrawingTests`（3 项）、`OneTapeHalftoneArtworkTests`（3 项）共 13 项模型与图像渲染单元测试全部通过，0 失败／跳过。** Debug 构建（`0.4.0 / build 96`）已生成并保留沙盒数据覆盖安装、启动到 `Stillroom iPhone 16 Pro`（`77CFAADC-0D5D-4E5B-864A-B5019465A476`，PID `19369`），主页已有歌曲与经典白壳外观保留完整。按用户「你不用检查，构建完即可，我来验证」指示，已中止未完成的 QA 自动化 UI 测试进程；全部实际手势交互、相册选图、Vision 实景抠图、分享导出及 16 款壳体实机视觉效果由用户亲自验证。

---

## 2026-11-10 / build95 磁带栏无用资源与冗余代码清理（仅模拟器调试包预览）

按用户要求仅对「自定义 → 磁带」栏目执行无用资产清理，保持「印花」「卷盘」「机身」「屏幕」四个栏目及所有现役磁带图像质量／分辨率原封不动：
- **移除 31 组未使用的磁带 `.imageset`**：19 组旧版开放式模塑资产（`OneTapeMould{Strata,Facet,Islands,Ribs,Stream,Eclipse}`、`Hub0/1`、`OneTapeMouldTape`）、6 组 `OneTapeMould*Thumb`、6 组 `OneTapeStyle*Thumb`，共移出约 `12.19 MB`（`Assets.car` 计入尺寸）至被忽略目录 `Artifacts/archive-unused-cassette-assets-20261110/` 备份留存。
- **清理冗余代码**：移除 [`OneTapeCustomizationTile.swift`](Stillroom/Features/OneTape/Customization/OneTapeCustomizationTile.swift) 中不再被调用的 `OneTapeAppearance.TapeStyle.customizationThumbnailAsset` 属性，保持 `OneTapeCustomizationTile` 与 `Doodle`（`印花`）资源完好。

**源码检查通过（385 文件、最大 666 行）；按用户「不要测试，构建到模拟器就行」要求未运行 XCTest、未构建 Release 真机包、未向 USB 真机安装。** Debug 包（`0.4.0 / build 95`）已构建并保留数据覆盖安装到当前开启的 `Stillroom iPhone 16 Pro`（iOS 27.0）模拟器（PID `48649`），启动截图正常；模拟器 `Assets.car` 为 `69.73 MB`（其中 `OneTapeMould*` 由 `28.42 MB` 降至 `16.26 MB`，剩余 271 组图像含全部 36 项闭口模塑组件与 22 项印花资源，`StyleThumb` 为 0）；另经 `xcrun devicectl list devices` 核对当前仍无 `transportType: wired` 的 USB 有线 iPhone。

---

## 2026-11-10 / build94 磁带自定义四组排序与命名调整

将全部 16 款磁带在「自定义 → 磁带」中重新归类排序，并保留 `.classic`（`白色`）作为默认外观：
1. **经典**：`白色`（`.classic`，默认）→ `黑色`（`.graphite`），置于最上方第一行；
2. **精工**：`桁架`（`.armature`）、`档案`（`.fieldNotes`）、`银铝`（`.silverOval`）、`双弧`（`.twinArc`）；
3. **模塑**：`岩层`（`.strata`）、`折面`（`.facet`）、`浮岛`（`.islands`）、`肋骨`（`.ribs`）、`流线`（`.stream`）、`月蚀`（`.eclipse`）；
4. **复古**：`透明`（`.clear`）、`窗口`（`.window`）、`Memphis`（`.memphis`）、`古铜`（`.bronze`）。

同时将非模塑选项缩略图统一为完整整带比例，消除局部裁切与整带缩略图并排时的大小差异；`OneTapeCustomizationUITests` 与 `OneTapeReelMotionUITests` 同步补充了针对下移项的滚动定位。

**源码检查通过（385 文件、最大 666 行）；隔离模拟器 `One Tape Mould QA`（iOS 27.0）中 `OneTapeAppearanceTests`（7 项）与 `OneTapeReelGearTests`（5 项）共 12 项单元／渲染测试以及 `OneTapeGlassUITests`（2 项）、`OneTapeOriginalMaterialUITests`（1 项）、`OneTapeReelGearUITests`（1 项）共 4 项 UI 流程全部通过，0 失败／跳过。**（另记：早期全跑 `OneTapeCustomizationUITests` 与 `OneTapeBronzeUITests` 时暴露过时测试仍查找已精简的 `water` 屏幕样式与旧文案 `One Tape 印字`，属于已有历史测试遗留，未在本轮顺带改写无关断言。）

**新包构建与交付边界（0.4.0 / build 94）：**
- **模拟器开发包预览**：已构建 Debug 模拟器包并保留数据覆盖安装、启动到当前开启的 `Stillroom iPhone 16 Pro`（iOS 27.0）模拟器（PID `36667`）。
- **真机 Release 安装包**：已通过 `xcodebuild -configuration Release -destination 'generic/platform=iOS' clean build` 构建、严格签名校验（`codesign --verify --deep --strict`）并核验无 `XCTest` 插件，产物保存在 `Artifacts/OneTape-0.4.0-build94/Stillroom.app` 与 `Artifacts/OneTape-0.4.0-build94-development.ipa`（SHA256: `2b71b1c18faa869123381088999d15ee5b1cba95085a6f9bcd94fc02a7bcb06b`）。
- **真机未安装说明**：经 `xcrun devicectl list devices` 核对，当前仍无 `transportType: wired` 的 USB 有线 iPhone 连接（「媒体播放器」iPhone 16 Pro / iOS 27.0 仅处于 `localNetwork` / `disconnected` 状态，「iPhone」15 处于 `unavailable` 状态），未进行真机覆盖安装或真机验收。

---

## 2026-11-10 / build93 全磁带样式卷盘齿轮着色与结构修复

修复古铜（`.bronze`）及四款新设计（`.armature` 骨架、`.fieldNotes` 纸本、`.silverOval` 银铝、`.twinArc` 双弧）在「自定义 → 卷盘」选色时齿轮颜色与结构不统一的问题，并消除六款立体模塑在选色时的底图齿轮齿尖漏边：
- **古铜（`.bronze`）**：保留外圈白色刻度表盘、红弧块与小轮外圈刻度环，中心上下两处均改为标准的 [`OneTapeReelGearView`](Stillroom/Features/OneTape/Player/OneTapeReelGearView.swift)（深灰边框 + 彩色 6 齿内环 + 深灰三爪鼓 + 静止高光银轴芯），替代原本无齿的细蓝环与右轮中空底槽。
- **4 款新设计**：保留各自外盘机械特征，选色时替换掉原本单薄的细线中心圈，统一挂载完整 `OneTapeReelGearView`；将 `.fieldNotes` 窗口轮廓改为 `Path.union` 真实并集，消除黑线横穿压在卷盘上的遮挡；将 `.silverOval` 的中心锁紧圈与平衡钉在选定自定义齿轮色后转为中性深钛灰，消除与亮橙圈的撞色冲突。
- **6 款立体模塑**：将覆盖齿轮外径比例 `gearOuterRadiusFraction` 从 `0.96` 调整至 `1.0`，避免露出底层驱动轮素材的银灰齿尖边。

**源码检查通过（385 文件、最大 666 行）；隔离模拟器 `One Tape Mould QA`（iOS 27.0）中 22 项模型／渲染 XCTest（含全 16 款磁带着色、旋转与轴芯亮度断言及 `fieldNotes`/`silverOval` 专项断言）与 1 项 `OneTapeReelGearUITests` UI 闭环测试全部通过，0 失败／跳过；已导出并检视 3x 修复后渲染拼图与 UI 测试截图。**

**新包构建与交付边界（0.4.0 / build 93）：**
- **模拟器开发包预览**：已构建 Debug 模拟器包并保留应用沙盒数据覆盖安装、启动到当前开启的 `Stillroom iPhone 16 Pro`（iOS 27.0）模拟器，截图核对古铜 + 蓝色齿轮在播放器主页渲染正确、原有歌曲与状态完整保留。
- **真机 Release 安装包**：已通过 `xcodebuild -configuration Release -destination 'generic/platform=iOS' clean build` 构建、严格签名校验（`codesign --verify --deep --strict`）并核验无 `XCTest` 插件，产物保存在 `Artifacts/OneTape-0.4.0-build93/Stillroom.app` 与 `Artifacts/OneTape-0.4.0-build93-development.ipa`（SHA256: `462801dfb794cc62eb345447349d5ed6dca19491e0ea3aa0142ab5e8efe13e97`）。
- **真机未安装说明**：经 `xcrun devicectl list devices` 核对，当前仍无 `transportType: wired` 的 USB 有线 iPhone 连接（「媒体播放器」iPhone 16 Pro / iOS 27.0 仅处于 `localNetwork` / `disconnected` 状态，「iPhone」15 处于 `unavailable` 状态），未进行真机覆盖安装或真机验收。

---

## 2026-11-08 / build92 磁带架叠放与旋转打开修复

对照工程内原版 USB 录像，叠放侧脊、封面和背面改用同一盒体投影与接缝；点击时沿用被点侧脊的位置和实际观察角度，完成旋转、上移及落位停顿后再显示歌曲列表。网格继续进入竖版详情。交接结束即移除浮动投影，避免透明转场层挡住封面点击；详情封面保留独立点击区域，点封面和返回按钮均可放回。

源码约束检查通过；最终同一验收运行中9项几何／原生绘制 XCTest 和1条完整交互回归全部通过，0失败／跳过。隔离 iPhone 16 Pro / iOS26.5 模拟器使用12张生成的几何封面及静音 WAV，覆盖滚动后上／中／下三处选择、同专辑标题、横竖详情、点封面放回和样式切换；已查看实际截图及逐帧旋转录屏。普通 Release build92经干净构建及严格签名校验通过，包含当前USB手机的开发描述文件，不含 XCTest 插件；开发安装包保存在被忽略的 `Artifacts/OneTape-0.4.0-build92-development.ipa`。没有导入用户音乐，也没有改动其他工程。

**build92现已安装并正常启动到USB wired「媒体播放器」iPhone16Pro / iOS27.0。** 初次安装曾被3个免费开发签名名额限制拦住，用户随后明确授权移除 Soliora；已只移除 `com.lh.Soliora`，再完成 One Tape 全新安装并核对版本92。初次运行出现开发者信任提示；用户允许信任后复查应用已进入开场，后续普通启动成功。通过手机镜像检查了开场进入播放器、打开导航并进入稳定的空曲库磁带架页面。未进入设置作额外修改，其他应用保持。

这台手机尚无音乐，因此有内容的叠放、选带旋转与歌曲交互仍只完成上述模拟器验证；没有向真机导入合成或用户音乐，未执行真机 XCTest 或音质验收。没有清理 One Tape 数据或修改签名身份。

[实际旋转预览（模拟器）](Evidence/0.4.0/library-stack-repair-20261108/rotation-preview.gif) · [叠放截图对比](Evidence/0.4.0/library-stack-repair-20261108/shelf-comparison.png) · [完整凭据](Evidence/0.4.0/library-stack-repair-20261108/BUILD_RECEIPT.json)

---

## 2026-11-08 左侧音乐菜单展开与图标点击（镜像观察、模拟器验证）

只调整底部菜单：歌曲信息、展开宽度与独立胶囊底板归最左侧播放器按钮所有，切到磁带架后保留自己的底板和清晰读数；点文字区仍返回同一首歌。其余两个入口宽度、右侧操作位置、原安全区边距与暂停信息策略保留。

通过 iPhone 镜像查看原版播放器、磁带架和图标响应；保留完整磁带壳体／双轴与四根带脊轮廓，点击时轴芯转动、带脊抬起／倾斜后回弹，同一菜单重复点击也触发。洞察和右侧系统图标使用原生分层回弹，减少动效分支保持静态。未修改播放业务、页面内容、磁带材质或签名配置。

**源码检查通过（365文件、最大641行）；普通模拟器 Xcode 构建、安装与启动成功；8项针对性 XCTest 通过，0失败／跳过。** 包含每个图标实际非空绘制、跨页边距、左侧独立底板、点击文字区返回，以及用新建20秒静音音频从未播放状态启动真实引擎，确认仅左侧音乐项展开、其余入口宽度及右侧按钮位置不变。已查看实际点击录屏与逐帧图，正常 App 不含 XCTest 插件。

原版当前为空库，未观察到真实歌曲的播放／暂停展开，也未逐帧还原其精确动画曲线；本次播放展开用独立模拟器合成音频验证。原版空库仅见播放器／磁带架，本项目既有第三个洞察入口按原需求保留。中间系统符号名导致的空白磁带图标已由截图和失败测试发现并移除，最终保留原生绘制的磁带轮廓。

沿用共享工程0.4.0/91，本轮未增加版本号。依用户要求，本应用只交付到 iPhone 16 Pro / iOS 26.5 隔离模拟器；镜像仅用于观察原版，没有把修复安装到 USB 手机或镜像手机。iOS 18 实际运行、其它窗口／辅助功能组合和主观音质未验收。并行磁带工作保留，未列为本轮验收。

[实际点击与展开预览](Evidence/0.4.0/navigation-left-expansion-20261108/menu-preview.gif) · [菜单截图对比](Evidence/0.4.0/navigation-left-expansion-20261108/menu-comparison.png) · [完整凭据](Evidence/0.4.0/navigation-left-expansion-20261108/BUILD_RECEIPT.json)

---

## 2026-11-08 底部菜单边距与 iOS 26 样式（仅模拟器验证）

只修改底部菜单：由根页面的窗口安全区统一承载，播放器与磁带架共用左右16逻辑点边距、72逻辑点高度及底部基线。去掉额外向下9点的偏移，页面内容的全屏绘制不再决定菜单布局。保留歌曲信息展开、暂停信息、三个原入口、随页操作与现有播放状态。

iOS 26 底部两块表面使用同一 `GlassEffectContainer` 和系统交互玻璃，去掉菜单专用的黑色染色与重复手动缩放；其明暗由背景决定。iOS 18 沿用已有材质与按压兼容分支。顶部设置按钮、播放器绘制、磁带架内容与音乐逻辑未由本任务修改。

**源码约束检查通过（365文件、最大641行），实际普通模拟器 Xcode 构建成功，3项导航状态 XCTest 与2条切页 UI XCTest 通过，0失败。** 隔离 iPhone 16 Pro / iOS 26.5 模拟器覆盖空库与合成长歌名的暂停恢复状态，每种状态连续切页五次，并检查截图。初始空库最终坐标未复现跨页差异，但独立检查确认旧菜单下缘超出安全区9点；修复后安全区、两端边距及跨页坐标检查均通过。

依用户本轮要求使用模拟器；手机由另一聊天使用，本轮没有真机安装、启动或验收，也未制作新的真机签名交付包。项目版本号保持0.4.0/90；下方原build90真机凭据属于此前印花交付，不包含本轮菜单修改。iOS 18 实际运行、其它窗口尺寸及主观音质未验收。保留共享工程中并行磁带修改，不作为本轮菜单验收范围。

[菜单对比截图](Evidence/0.4.0/bottom-navigation-20261108/navigation-margin-comparison.png) · [检查与构建凭据](Evidence/0.4.0/bottom-navigation-20261108/BUILD_RECEIPT.json) · [Apple 交互玻璃说明](https://developer.apple.com/documentation/swiftui/glass/interactive(_:))

---

## 0.4.0 / build90 印花统一，品牌文字独立

按用户纠正恢复统一印花：同一图案在六款模塑上使用完整原资源、相同尺寸、方向、中心、墨色和同一机构避让遮罩。撤掉89中的壳面专属落点、人物分拆、城市节选、枝鸟重排及各壳光照取样；不同壳面的文字区与透明边框不再单独裁掉图案。品牌文字继续保留各款排版；选择插画时，将真实曲数与总时长放到统一印花下方的文字区。已确认的六款壳面、轴芯动画、原队列数据与当前组合预览保留。

**正常签名 build90 构建成功，并保留数据覆盖安装到当前 USB wired iPhone15 / iOS26.6，由89更新为90。** 源码约束检查通过（365文件、最大641行），严格签名校验通过，1029个源码／资源／工程／工具文件构建至安装快照一致，冻结副本与原产物字节哈希一致。

新增同一印花跨六款像素一致的回归断言源码，但按用户“验证交给我”的要求未执行 XCTest、模拟器、App启动或真机页面检查；最终视觉、文字间距与交互仍由用户验收。未卸载、清数据、改签名身份或读取用户音乐，原位更新保留数据，未检查其内容。下方89的印花重排过程为被用户纠正的历史。

[交付凭据](Evidence/0.4.0/unified-print-layer-20261108/BUILD_RECEIPT.json) · [统一印花说明](Docs/ONE_TAPE_UNIFIED_PRINT_LAYER_2026-11-08.md)

---

## 0.4.0 / build89 六款收口模塑与印花兼容

接入用户确认的岩层、折面、浮岛、肋骨、流线、月蚀六款立体摄影壳面，大部分带卷藏入壳内，保留小轴芯与观察缝。素材里的固定示意印字已移除，原生文字继续显示真实曲数、总时长与可选品牌；只有驱动芯沿原有视觉相位转动。

五种印花按壳面重新编排：小狗与毛毛虫等比落在各自实体区域；跷跷板人物分区；城市保留天际线，植物分成两组枝鸟。油墨采用当前壳面的明暗，避开轴芯、窗口、读数与底部机构。磁带预览保留当前印花，模塑的印花选项直接显示实际组合，沿用播放器的同一读数。

**正常签名 build89 构建成功，并保留数据覆盖安装到当前 USB wired iPhone15 / iOS26.6，由88更新为89。** 源码约束检查通过（365文件、最大641行），严格签名校验通过，构建至安装的1029个源码／资源／工程／工具文件快照一致；冻结副本与构建产物哈希一致。保留共享工程现有磁带架、菜单与横竖详情工作。85、87中间包均未安装。

按用户“构建到手机，验证交给我”的要求，未运行 XCTest、模拟器、App启动或真机页面检查。离线素材组合图仅用于编排，未覆盖原生最终遮罩、玻璃和实时文字，不能视为视觉验收；最终组合、交互、旋转与音质由用户验收。未卸载、清数据或读取用户音乐，原位更新保留数据，未检查其内容。

[交付凭据](Evidence/0.4.0/approved-print-friendly-moulds-20261108/BUILD_RECEIPT.json) · [设计与接入说明](Docs/ONE_TAPE_APPROVED_CLOSED_MOULDS_2026-11-08.md)

---

## 0.4.0 / build88 两种入口对应横竖详情顶部

叠放磁带架进入原版横向详情顶部：左侧方形专辑封面，右侧专辑名与艺人信息纸面；网格进入竖版详情顶部，保留封面下的标题与艺人。只分顶部，下面的播放／随机播放按钮、歌曲列表、收藏、当前歌曲启停和音效继续共用原实现及同一个引擎。选中专辑时记录入口样式，保留的详情页继续使用打开时的格式。

入场浮动封面、落位尺寸和最终封面使用同一横竖格式，叠放盒体的正反面与透视恢复为横版。原来的窗口居中、整行滚动定位、菜单样式选择与重新加载动画保留。横版C46为参考磁带的固定印字，与实际媒体时长分开。

**正常签名 build88 构建成功，并保留数据覆盖安装到当前USB wired iPhone15 / iOS26.6，由86更新为88。** 源码约束检查通过（364文件、最大641行），构建前后完整源码／资源快照一致。既有开封几何测试源码已更新，尚未运行；并行磁带更新保持，不作为本轮详情顶部任务验收。

继续按用户「不用检查，我来验证」要求，未运行XCTest、模拟器或真机页面检查，安装后未启动App；两种顶部与过渡效果由用户验收。未卸载、清数据、修改沙箱或复制用户音乐，原数据通过原位更新保留，未检查其内容。

[交付凭据](Evidence/0.4.0/library-dual-detail-headers-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build86 样式切换居中与整行滚动定位

两种磁带架样式统一固定为当前窗口宽度，切换时使用独立的滚动视图身份，重新入场只沿竖向缩放和移动。网格由单张封面的滚动目标改为完整双列行：每行的定位中心与窗口中心重合，奇数末行也保留第二列空位；旧的右列定位会归一到同一行。叠放磁带架的滚动目标同样铺满窗口，盒体在行内居中。保留原封面大小、间距、文字、菜单入口、缓存、浏览位置和音效路径。

**正常签名 build86 构建成功，并保留数据覆盖安装到当前USB wired iPhone15 / iOS26.6，由84更新为86。** 源码约束检查通过（364文件、最大641行），构建前后完整源码／资源快照一致。并行磁带更新保持，不作为本轮布局任务验收。

源码检查发现单列封面定位与未显式固定的横向尺寸存在偏移风险，本轮未独立重现手机现象。继续按用户「不用检查，我来验证」要求，未运行XCTest、模拟器或真机页面检查，安装后未启动App；反复切换与恢复位置后的最终居中效果由用户验收。未卸载、清数据、修改沙箱或复制用户音乐，原数据通过原位更新保留，未检查其内容。

[交付凭据](Evidence/0.4.0/library-layout-centering-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build84 原功能弹窗顶部横排样式选择

撤掉单独的样式切换按钮，恢复左上角原功能按钮。点击后，在原生弹出菜单最上方横向排列「叠放／网格」两个选项，下面继续显示原筛选、排序和设置；「添加音乐」继续从该菜单移除。选中其他样式后收起菜单，沿用原来的收起、加载指示、逐行展开动画及浏览位置；当前样式不重复加载。

**正常签名 build84 构建成功，并保留数据覆盖安装到当前USB wired iPhone15 / iOS26.6，由83更新为84。** 源码约束检查通过（364文件、最大641行）。首包构建后检测到四个并行磁带绘制文件更新，安装前已停止，保留更新并重新构建；最终完整源码／资源快照核对一致后完成安装，首轮记录保留。并行磁带绘制不作为本轮菜单任务的验收。

未卸载、清数据、修改沙箱或复制用户音乐；原数据通过原位更新保留，未检查其内容。继续按用户「不用检查，我来验证」要求，未运行XCTest、模拟器或真机页面检查，安装后未启动App；最终弹窗横排、选中状态、收起行为和切换动画由用户验收。

[交付凭据](Evidence/0.4.0/library-menu-layout-palette-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build83 当前歌曲磁带按钮与启停显示

专辑详情的歌曲行改为原生按钮：点击当前歌曲播放／暂停，点击其他歌曲选择并播放；当前行切换继续使用原引擎、队列和媒体位置。启停经已有OneTapeMusicStore回调，沿用真实引擎确认后的机械启动／停止音效。

参考照片中的磁带轮廓，当前歌曲播放时带盘展开、亮起并转动，暂停时带盘收合为窄槽并静止变暗，短过渡连接两种造型。小图标以独立视觉时间绘制，暂停、离页、后台及减少动态效果时暂停时钟；减少动态效果时省去开合补间。整行可点击，保留收藏长按、辅助功能标签和播放／暂停状态。

**正常签名 build83 构建成功，并保留数据覆盖安装到当前USB wired iPhone15 / iOS26.6，由82更新为83。** 源码约束检查通过（364文件、最大641行），构建源码快照无漂移。已有并行资源准备文件予以保留，不作为本轮新增或验收。未卸载、清数据、修改沙箱或复制用户音乐；原数据通过原位更新保留，未检查其内容。继续按用户「不用检查，我来验证」要求，未运行XCTest、模拟器或真机页面检查，安装后未启动或试听；实际点击、图标开合与主观启停音效由用户验收。原版暂停态未独立核实，不声称逐像素一致。

[交付凭据](Evidence/0.4.0/album-row-tape-toggle-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build82 顶部入口精简与样式重新入场

移除磁带架顶部菜单里的「添加音乐」。左上角切换叠放／网格时，先收起当前内容，短暂显示切换加载指示，再从保留的浏览位置逐行展开目标样式；顶部工具栏保持原位。切换使用现有曲库与封面缓存，保留搜索、筛选、排序和样式偏好。

普通动效约0.86秒，逐行延迟按当前浏览位置计算并封顶，深处条目不会产生长等待。切换期间暂缓重复点击与封面选择；离页、切后台或移除视图会取消任务，旧取消回调不会重置后续切换。减少动态效果时使用短淡入淡出，关闭位移、缩放与逐行延迟。

**正常签名 build82 构建成功，并保留数据覆盖安装到当前USB wired iPhone15 / iOS26.6，由81更新为82。** 源码约束检查通过（363文件、最大641行），构建源码快照无漂移。未卸载、清数据、修改沙箱或复制用户音乐；原数据通过原位更新保留，未检查其内容。继续按用户「不用检查，我来验证」要求，未运行XCTest、模拟器或真机页面检查，安装后未启动App；最终重新入场动画及中断交互由用户验收。

[交付凭据](Evidence/0.4.0/library-layout-reload-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build81 双列竖版磁带架与样式切换

磁带架左上角改为直接切换 **叠放／封面网格**，原筛选与排序入口移到分段控件右侧，搜索仍在最右侧。新增参考图红框里的双列竖版磁带盒，封面下显示真实专辑名和艺人；两种样式共用搜索、筛选、排序和原封面缓存，各自保留浏览项位置，并记住样式选择。

共享封面与详情页统一为211.7:329竖版，使用原图等比铺满裁切，不旋转、拉伸或改写图片文件；详情页的专辑名与艺人移到封面下方。网格选中从实际封面位置抬起并进入详情，原叠放样式保留向后翻转与滚动音效／触感路径。两种样式用短促缩放、位移和淡入淡出切换，减少动态效果时使用短淡入淡出。

**正常签名 build81 构建成功，并保留数据覆盖安装到当前USB wired iPhone15 / iOS26.6，由80更新为81。** 源码约束检查通过（363文件、最大641行），构建源码快照无漂移。未卸载、清数据、修改沙箱或复制用户音乐；原数据通过原位更新保留，未检查其内容。继续按用户「不用检查，我来验证」要求，未运行XCTest、模拟器或真机页面检查，安装后未启动App；最终排版、封面裁切、浏览位置与切换动画由用户验收。既有开封几何测试源码已随竖版调整，尚未执行。

[交付凭据](Evidence/0.4.0/library-portrait-grid-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build80 暂停信息、两端固定与纯图标操作

底部播放器菜单在当前歌曲已有真实播放记录时保留歌名与作者，暂停和冷恢复均沿用现有历史；尚未播放过的预选歌曲才保持紧凑。左侧菜单固定在左侧，右侧操作固定在右侧，保留安全区内16逻辑点边距和统一72逻辑点高度，紧凑状态的多余空间由中间弹性间距吸收。移除右侧「导入」字样，导入换成原生「＋」图标；辅助功能标签和歌曲信息继续保留。三个菜单、右侧操作及既有点击动效沿用，洞察内容仍留空。

**正常签名 build80 构建成功，并保留数据覆盖安装到当前USB wired iPhone15 / iOS26.6，由79更新为80。** 源码约束检查通过（362文件、最大641行），构建源码快照无漂移。未卸载、清数据、修改沙箱或复制用户音乐；数据通过原位更新保留，未检查其内容。按用户延续的「不用检查，我来验证」要求，未运行XCTest、模拟器或真机页面检查，安装后未启动App；最终布局、暂停显示和图标效果由用户验收。

[交付凭据](Evidence/0.4.0/navigation-paused-edges-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build79 六款原创模塑构件重做

对照原版13款模塑的本地缩略图，把六款重做为固定内部机构与原生模塑外壳分层：统一两处驱动轴、小尺寸黑色齿芯、独立浅色轮盘、褐黑圆形带卷、底部梯形结构和四个导向开孔。岩层、折面、浮岛、肋骨、流线、月蚀分别通过台阶、斜撑、分区框、细肋、曲线和月牙窗口区分。中央独立小窗属于可变元素，不再被当作所有模塑的必需件。

修正实体壳面透出隐藏机构、筋线穿过印字区的问题；深色款同步调整印花对比色。选择卡与主页共用几何，缩略图和自定义预览省略缩小后会产生波纹的超细圈纹与颗粒，主页保留细节。磁带身份、实际队列读数及原有等大、同速、暂停相位保持。

**正常签名 build79 已保留数据覆盖安装到 USB wired iPhone15 / iOS26.6，检查后已无参数普通启动。** 源码检查通过（362文件、最高641行），实际 Xcode 构建和严格签名核验通过，正常 App 无 XCTest 插件。最终版本23项模型／绘制检查及1条六款真机流程通过，0失败／跳过；真机覆盖六款选择、玻璃开合和冷恢复，已查看最终手机截图与选择列表。选定曲库索引与正常外观值 SHA256 前后一致，保留用户的肋骨选择，没有卸载、清数据或复制用户音乐。

UI流程使用独立空库外观。原版仅观察本地缩略图，新壳面为二维原生绘制；未验收原版付费完整材质、全部设备／辅助功能／印花组合、长时实播、能耗或音质。前一轮78与中间失败证据保留，最终验收限定79，不累计重复测试数。

[构件分析与修改说明](Docs/ONE_TAPE_MOULD_STRUCTURE_2026-11-08.md) · [六款最终真机画面（裁切、旋转）](Evidence/0.4.0/mould-structure-redesign-20261108/phone79-images/six-phone-moulds-cropped-rotated.png) · [交付凭据](Evidence/0.4.0/mould-structure-redesign-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build77 底部菜单与随页操作

左侧胶囊改为播放器、磁带架和洞察三个菜单，右侧随当前菜单显示自定义、导入和设置。左右玻璃表面统一为72逻辑点高并居中对齐。播放器仅在实际播放时展开歌名与作者，暂停或未播放时收成图标；从其他菜单返回播放器后，操作区继续可见，并沿用原有闲置隐藏计时。

加入点击压感、选中胶囊过渡和图标内部短动画：带盘转动、磁带盒轻抬、洞察柱条回弹；减少动态效果时关闭这些位移和缩放。导入沿用已有音乐来源面板。按用户补充，洞察只接菜单选中与右侧操作，页面内容留空，不新增统计。

**正常签名 build77 构建成功，并按用户后续要求保留数据覆盖安装到当前USB wired iPhone15 / iOS26.6，由原build76更新为77。** 未卸载、清数据、修改沙箱或复制用户音乐；数据沿用原应用容器，未检查内容。源码约束检查通过（361文件、最大641行），构建源码快照无漂移。按用户「不用检查，我来验证」的要求，未运行XCTest、模拟器或真机页面检查，安装后未启动App；视觉、菜单交互和动效效果由用户验收。

[构建凭据](Evidence/0.4.0/contextual-navigation-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build76 连续磁带入场与箭头引导

优先重做转正到主页的衔接：开屏直接驱动 **主页同一盘磁带** 的位置、角度与大小，沿用其当前材质、玻璃状态和卷轴视觉相位。移除开屏另画的磁带及磁带机；转90°与靠近动作连续衔接，真实机身在磁带周围显现，结束时回到正常播放器的同一位置与尺寸，不再换图或重建带盘时钟。

盒内磁带先保留正确留边，开盒后再提起、由小到大靠近展示，盒子向后退去。开屏额外玻璃动作已移除，不再写入玻璃开关。页面去掉大段文案、步骤标语与底部引导文字，仅保留方向箭头和「跳过」；纸封保留 One Tape 和 A。设置首屏 **开屏动画 → 重新演示** 入口继续保留。

**正常签名 build76 已保留数据覆盖安装到 USB wired iPhone15 / iOS26.6，并无参数普通启动。** 源码检查通过（361文件、最高641行），实际 Xcode 构建和严格签名核验通过，正常 App 无 XCTest 插件。最终安装前后的选定曲库索引、正常外观值 SHA256 和开屏完成标记一致；未卸载、清数据或复制用户音乐。

延续用户上一轮「不用验证，构建到手机」的要求，本版未运行 XCTest、页面或交互验证。相关测试源码已随展示字段调整，但未执行；旧版画面、短片与测试不作为本版视觉验收。最终比例、衔接节奏和手势体验留待用户查看。

[本轮交付凭据](Evidence/0.4.0/opening-continuous-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build75 八款机身合并与磁带框边界

**自定义 → 机身** 中，原四款照片预览与新四款玻璃／金属材质合并到同一个双列列表，色卡统一放在八款下方。原四张预览素材 SHA256 保持一致。

按照用户照片标出的完整磁带框，机身配色与材质只绘制在框外；磁带自身的框沿、深色底座、阴影、印花和带盘不受机身覆盖，玻璃开合使用同一边界。移除框外额外叠加的宽黑描边，保留磁带模块本身的原始边框。

**正常签名 build75 已保留数据覆盖安装到 USB wired iPhone15 / iOS26.6，检查后无参数普通启动。** 源码检查通过（361文件、最高641行），实际 Xcode 构建和严格签名核验通过，正常 App 无 XCTest 插件。24项针对性模型／绘制检查及1条真机流程通过，0失败／跳过；模型检查覆盖12款磁带、玻璃两态及7种机身配置的框内像素。实际查看了材质应用、合并列表与正常主页的手机截图。冻结产物与源码快照已保留；后续共享卷轴改动单列，不纳入本轮产物验收，本轮机身相关文件未漂移。

曲库索引 SHA256 前后一致，未卸载、清数据或复制用户音乐。正常屏幕、机身款式及磁带款式期间有三项偏好变化，原因未单独确定，保留当前值而未回写覆盖。真机流程使用独立空库外观；完整设备／辅助功能矩阵、长时能耗及新材质下实播未验收。本轮验收限定机身列表和磁带框边界，不替代并行开屏、来源开关或卷轴任务的验收；同号75产物以凭据路径和哈希区分。

[交付凭据](Evidence/0.4.0/body-unified-pocket-20261108/BUILD_RECEIPT.json) · [真机机身列表与色卡](Evidence/0.4.0/body-unified-pocket-20261108/phone-images/unified-body-colors-after-all-eight-choices.png) · [真机雾面玻璃与磁带框](Evidence/0.4.0/body-unified-pocket-20261108/phone-images/original-material-frostedGlass-applied.png)

---

## 0.4.0 / build75 上滑开盒与90°入仓

开屏先展示完全闭合、带纸封的磁带盒。向上滑动后开盒并提起当前磁带，停留供用户左右轻拖转动查看；再从右向左滑动，磁带顺时针转90°，同步放大并对齐到播放器内的实际磁带位置与尺寸，然后渐入磁带机、向上打开玻璃，衔接原主页。设置首屏保留 **开屏动画 → 重新演示**。首次完成标记、按钮替代操作、减少动态效果和后台取消逻辑继续保留。

**正常签名 build75 已保留数据覆盖安装到 USB wired iPhone15 / iOS26.6，并无参数普通启动。** 源码检查通过（361文件、最高641行），实际 Xcode 构建及严格签名核验通过，正常 App 没有 XCTest 插件。最终覆盖安装前后的曲库索引、正常外观值 SHA256 和开屏完成标记一致；未卸载、清数据或复制用户音乐。

按用户最新要求，最终90°版本没有运行 XCTest、页面或交互验证。此前71/74的45°演示和检查属于历史证据；74曾出现重播检查失败，本版移除了盒面直接点击手势，尚未复测。主观声效、触感及最终动效不在本版验收范围内。

[本轮交付凭据](Evidence/0.4.0/tape-opening-gestures-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build73 移除主页左上角来源开关

移除主页左上角的音乐来源开关及开屏卡座中的同一图形，原位置补齐当前机身材质；保留设置中已有的「添加音乐」入口。

**正常签名 build73 构建成功。** 按用户「不用检查，构建就行。我来验证」的最新要求，本任务止于构建，未安装、启动或进行真机页面验收；此前已结束的检查不作为本轮真机视觉验收。共享版本号随后由其他工作推进至74，本任务保留冻结73产物，不回退版本号或覆盖手机。

[构建凭据](Evidence/0.4.0/remove-source-switch-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build70 肋骨磁带孔边与带卷毛边修复

肋骨款十二个孔口分别对齐实际壳体轮廓，清理镜像遮罩留下的残片；黑色带卷改为原生纹理，去掉旋转素材中的塑料亮圈。选择卡同步生效，保留左右等大、同速和现有播放状态。

**正常签名 build70 已保留数据覆盖安装到 USB wired iPhone15 / iOS26.6，并在检查后无参数普通启动。** 源码检查、实际 Xcode 构建、严格签名核验、15项模型／绘制检查和1条肋骨真机流程通过。已查看播放、暂停、开盖与合盖的实际手机截图；肋骨＋默认 LCD 播放抽测平均59.56帧／秒。曲库索引保持，前后正常外观有四项值变化，原因未单独确定，未回写覆盖。后续共享源码的轴芯旋转规则另行验证，本段证据限定冻结70产物；其他五款仅做绘制回归，完整机型／屏幕组合、长时能耗与主观音质未在本轮验收。

[修复说明](Docs/ONE_TAPE_RIBS_EDGE_CLEANUP_2026-11-08.md) · [真机截图](Evidence/0.4.0/ribs-edge-cleanup-20261108/phone-images/ribs-after.png) · [交付凭据](Evidence/0.4.0/ribs-edge-cleanup-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build69 机械入场与设置首屏重新演示

**设置首屏最上方增加「开屏动画／重新演示」卡片**，打开设置即可点击；移除「关于」列表深处的旧入口。开屏改为分阶段的机械入场：透明磁带盒盖转开、磁带提起出盒、空卡座随转正动作出现、玻璃合上后锁扣回弹、屏幕通电，最后衔接实际播放器。机身和按键沿用当前材质，开盒与入仓有独立透视、反射和阴影；装载过程约3.04秒。入场沿用原播放器，保留首次完成标记、外观与开盖偏好，减少动态效果时继续使用短淡入。

**正常签名 build69 已保留数据覆盖安装到 USB wired iPhone15 / iOS26.6，并在 XCTest 后无参数普通启动。** 源码检查通过（361文件、最大641行），实际 Xcode 构建及严格签名核验通过，正常 App 没有 XCTest 插件。22项模型／取消任务／反馈检查、3条真机流程通过，0失败／跳过；同样3条流程在独立模拟器重复通过，不计作6个独立用例。真机确认设置首屏无需滑动即可重新演示，覆盖点击、下滑入仓、跳过与冷启动，并查看实际设置和正常播放器。曲库索引与正常外观值 SHA256、首次完成标记前后一致，未卸载、清数据或复制用户音乐。

已查看原生动画中间帧和真机截图。本轮短片为原生 iOS 模拟器无声录制，声音／触感的主观效果、真机系统减少动效开关、完整设备／辅助功能矩阵仍未验收；本轮不替代其他卷轴或机身任务的验收。交付收据记录的 Swift 源码在封存时无漂移。

[本轮凭据](Evidence/0.4.0/tape-opening-mechanism-20261108/BUILD_RECEIPT.json) · [真机设置入口](Evidence/0.4.0/tape-opening-mechanism-20261108/phone-images/opening-settings-first-screen.png) · [原生模拟器动画实录（无声）](Evidence/0.4.0/tape-opening-mechanism-20261108/opening-native-simulator69-clean.mp4)

---

## 0.4.0 / build68 六款模塑磁带等大、同速与连接窗修复

岩层、折面、浮岛、肋骨、流线、月蚀每款左右带盘保持相同直径，卷带孔使用相同素材与尺寸；播放和正反快转使用相同角速度。完整覆盖孔内旧静态带盘，清除灰色扇区、折面孔边三角残片和双重轮缘；岩层、折面的中央带条改为平直连续，其余四款中央结构保留。选择卡同步使用修复后的原生组件。实际媒体时间与队列总时长继续来自原引擎。

**正常签名 build68 已保留数据安装到 USB wired iPhone15 / iOS26.6，15项模型／绘制检查和1条六款真机完整流程通过。** 逐款检查真实服务器队列播放、两处卷轴运动和玻璃开合；最终暂停的两张截图全部1,759,600个像素严格相同。岩层＋默认 LCD 实际显示采样平均59.22次／秒。源码检查、实际 Xcode 构建和严格签名校验通过，正常 App 无 XCTest 插件；正常外观偏好和 Navidrome 索引保持。中间几何断言和首轮原始截图内存比较失败保留在凭据中。

后续并行开屏 build69 已包含相同六个生产源码文件并普通启动，未覆盖回旧包；本段独立验收与帧率证据限定冻结68产物。长时能耗、所有屏幕组合与完整设备矩阵未验收。[修复说明](Docs/ONE_TAPE_MATCHED_MOULDS_2026-11-08.md) · [真机六款截图](Evidence/0.4.0/mould-matched-reels-20261108/phone-images/six-phone-overview.png) · [验收凭据](Evidence/0.4.0/mould-matched-reels-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build67 恢复印花玻璃与品牌印字开关

入口：**自定义 → 印花 → 向下滚动到底部**。恢复「玻璃：关闭／打开」和「品牌印字：关／开」。玻璃与既有滑盖手势共用同一外观状态，选择会保存。品牌开关控制现有 One Tape 配字；沿用插画与品牌互相替换的规则，开启品牌印字会切回「无」插画，页面同步说明。未改印花美术、屏幕或播放引擎。

**正常签名 build67 已保留数据覆盖安装到 USB wired iPhone15 / iOS26.6，检查后无参数普通启动。** 源码检查通过（360文件、最高641行），实际 Xcode 构建和严格签名核验通过，正常 App 无 XCTest 插件。13项外观／玻璃模型和既有滑盖 UI 检查通过；新增恢复流程最终在模拟器和正常真机包上各通过1次，均0失败／跳过，同一方法不累计成两个独立用例。覆盖开关应用、插画替换、冷启动保存，以及手势回写开关状态；实际查看原生模拟器和真机截图。

正常 Navidrome 索引 SHA256 和正常外观偏好前后一致；测试使用独立的空库外观偏好，没有卸载、清数据或复制用户音乐。初轮新增测试遇到 HUD 自动消失的导航竞态，修正测试同步后通过；初轮诊断清理停滞曾中断，保留失败记录，不将该次称为完整绿包。构建后并行卷轴／几何及版本68源码修改已保留，不归入本轮冻结67产物的验收；同号开屏67包为另一产物，以凭据的路径与可执行文件哈希区分。完整设备／辅助功能矩阵及实播音质未在本轮验收。

[恢复凭据](Evidence/0.4.0/restore-print-controls-20261108/BUILD_RECEIPT.json) · [真机印花开关](Evidence/0.4.0/restore-print-controls-20261108/phone-frames/9F49EAE7-CBDD-426E-9513-A96C5604D383.png)

---

## 0.4.0 / build67 磁带入仓开屏

首次启动展示暖棕底色与当前所选磁带。轻点「放入磁带」或向下轻滑，磁带转正落入主页卡座，合盖后配一次短促的锁扣音效与触感，再显露播放器。开屏与主页共用磁带材质、当前歌单读数和同一播放器；入场只改变视觉呈现。完成或跳过后保存独立标记，后续直接进入主页；可在 **设置 → 关于 → 重看开屏** 再次体验。减少动态效果时使用短淡入，跳过、切后台和离页会取消待执行的动画任务与音效。文案和跳过按钮使用窗口安全区，绘制层填满背景。

**正常签名 build67 已保留数据覆盖安装到 USB wired iPhone15 / iOS26.6，XCTest 后已无参数普通启动，并把正常首次开屏留给用户体验。** 源码检查通过（360 文件、最大641行），实际 Xcode 构建与严格签名核验通过，正常 App 没有 XCTest 插件。20项针对性模型／取消任务／反馈策略检查、3条真机 UI 流程通过，0失败／跳过；同样3条流程在独立模拟器重复通过，不累计为6个独立用例。实际查看了正常模塑磁带开屏、经典磁带开屏及入场后的暂停主页。正常曲库索引和外观值 SHA256 前后一致，正常首次开屏标记仍为未完成；未卸载、清数据或复制用户音乐。

小红书参考链接本轮无法访问，未声称逐帧复刻。主观声效／触感、真机系统减少动效开关及完整设备／辅助功能矩阵未在本轮验收。构建后共享源码出现并行卷轴／几何／播放页修改，已保留并在凭据中列明，不纳入本轮 build67 验收。首轮拖动测试的提前检查已修正，最终原生流程通过；原失败日志仍保留。

[本轮凭据](Evidence/0.4.0/tape-opening-20261108/BUILD_RECEIPT.json) · [正常真机开屏](Evidence/0.4.0/tape-opening-20261108/phone-images/opening-06-normal-launch.png) · [入场后的真机主页](Evidence/0.4.0/tape-opening-20261108/phone-images/opening-02-player.png)

---

## 0.4.0 / build65 四款原创玻璃与金属机身

入口：**自定义 → 机身 → 向下滚动到「原创材质」**。加入雾面玻璃、烟晶玻璃、拉丝铝、深色钛金属：玻璃有内层结构、边缘厚度与柔／硬反射，金属有固定细纹、不同宽度的反光带与切削边框，三颗按键使用相应表面。材质可搭配色卡；「原始质感」或原机身卡片可切回。四张 Cassette 原始预览及素材 SHA256 保留，新款单独展示。新增可选偏好字段兼容旧记录，未新增播放引擎、媒体时钟或传感器任务。

**冻结的正常签名 build65 已保留数据覆盖安装到 USB wired iPhone15 / iOS26.6，并在检查后无参数普通启动，末次核对仍为65。** 对应源码快照的检查通过（353文件、最高641行），实际 Xcode 构建和严格签名核验通过，正常 App 无 XCTest 插件。22项模型／绘制检查及1条真机流程通过，均0失败／跳过。真机覆盖四款预览与应用、控件可达性、固定按键尺寸、钛金属冷恢复及切回原始机身。

已查看原生绘制与实际手机截图。固定纹理在重复绘制检查中不闪动，避开磁带、屏幕和来源开关内容。原曲库索引 SHA256 保留，未卸载、清数据或复制用户音乐；正常屏幕偏好期间观测到从读数变为流体，未覆盖该选择，不声称全部偏好字节不变。材质是二维光学设计，完整设备／辅助功能矩阵、长时能耗和新材质下实播尚未在本轮验收；播放灯两态由绘制检查覆盖。

正常65产物冻结后，另一窗口继续加入开场与印花开关源码；这些较新文件已保留，另列于源码边界，不属于本轮65材质包验收。没有为完成此任务而回退并行工作。

[交付凭据](Evidence/0.4.0/original-body-materials-20261108/BUILD_RECEIPT.json) · [四款真机细节对比](Evidence/0.4.0/original-body-materials-20261108/phone-materials-comparison.png) · [原创材质选择器](Evidence/0.4.0/original-body-materials-20261108/phone-images/original-material-frostedGlass-picker.png) · [烟晶玻璃完整机身](Evidence/0.4.0/original-body-materials-20261108/phone-images/original-material-smokedGlass-applied.png)

---

## 0.4.0 / build61 播放页帧率与主线程开销

真机采样定位到轨迹屏逐像素计算占约 88% CPU 样本，并在主线程拖慢整页。缓存固定光轨数据，只更新发光像素；Rain／Trails 播放帧改为串行后台生成，最多一份执行中和一份最新待处理请求，暂停／离页会使过期结果失效。卷轴调度从 30 提至 60 Hz，六款磁带和既有切歌／转角规则保留。

**USB iPhone15 / iOS26.6 同场景实测：岩层＋轨迹平均呈现率 17.2 → 59.6 次／秒，约 6 秒 CPU 时间 6.453 → 2.874 秒，下降 55.5%；物理内存下降 14.6%。** 经典＋轨迹 CPU 同样由 6.472 降至 2.726 秒；当前正常外观的经典＋干邑＋电平屏平均 58.7 次／秒。帧率来自 Instruments 显示表面采样，未以配置的刷新率或为零的 hitch 指标冒充实测结果。

正常签名61包已保留数据安装并在最终测试后无参数普通启动。23项模型／并发／绘制检查、3个不同真机方法通过；额外正常外观采样是其中一方法的重复，不累计。实际检查播放、暂停像素冻结及正常主页，Navidrome 索引字节哈希不变，未卸载、清数据或复制用户音频。首次误附加 UI 运行器的 trace 已排除；一次 CoreDevice 连接失败后保留失败记录并重试通过。交付后共享元数据／缩略图源码变化单列，性能 Swift 源码仍与实测61一致。长时能耗与完整设备矩阵未验收。[性能说明](Docs/ONE_TAPE_PLAYBACK_PERFORMANCE_2026-11-08.md) · [量化对比](Evidence/0.4.0/cassette-performance-20261107/performance-comparison.json) · [交付凭据](Evidence/0.4.0/cassette-performance-20261107/BUILD_RECEIPT.json)

---

## 0.4.0 / build64 恢复机身弹窗的原始参考预览

撤回 build61 对机身卡片的实时重绘，恢复项目原有的四张 Cassette 参考缩略图：按键高光、石墨红色三角与深色屏框、随曲配色青灰示意、封面中性色示意均使用原素材。四张素材的 SHA256 未改。实际机身的随曲取色、石墨播放图标和固定尺寸播放键修复继续保留；不再用“预览与实际页面像素一致”作为验收要求。

**正常签名 build64 已保留数据覆盖安装到 USB wired iPhone15 / iOS26.6，并在检查后无参数普通启动。** 源码检查通过（346 文件、最大641行），Xcode 构建和严格签名核验通过，正常 App 没有 XCTest 插件。12项针对性模型／绘制检查及1条真机弹窗流程通过，0失败／跳过；实际查看了四款预览、选中状态、关闭返回和正常主页。正常偏好内容与曲库索引 SHA256 前后相同，未卸载、清数据或复制用户音乐。本轮验收限预览恢复及相关控件，未将实际机身或整个弹窗称为与 Cassette 逐像素一致，也未重做其他窗口的屏幕／性能验收。

[交付凭据](Evidence/0.4.0/body-picker-reference-20261108/BUILD_RECEIPT.json) · [恢复后的真机弹窗](Evidence/0.4.0/body-picker-reference-20261108/phone-images/reference-picker-graphite.png)

---

## 0.4.0 / build63 屏幕与三键仅允许左横

电子屏和左侧三个播放按钮共用朝向限制：竖持为竖向，左横持可转向，右横持或倒立竖持恢复竖向；平放、背放和未知朝向保留上一种合法状态。右横时不再反向旋转图标或交换上一首／下一首的位置。沿用上一轮屏幕过渡，未改播放引擎与媒体进度。

已更新独立原生 iOS 模拟器至 build63，并通过 Device Hub 实际核对左横、右横受限和回正时的屏幕／三键方向，最后正常无参数启动。源码检查（347 文件、最高 641 行）、实际 Xcode 编译及严格签名核验通过；同轮 **3 项针对性检查通过、0 失败／跳过**，包含朝向策略及两条真实 UI 流程。右横受限时，流体和名称页与竖排基准的像素严格一致；有曲状态的暂停时间、曲名、面标和五款布局均保持。旧 MusicStyle UI 的右横契约也已同步，但未将该未运行用例计入通过数。

本轮继续按用户指定的模拟器视查范围执行，未操作实体手机；此前双向横持的历史收据不代表当前规则。真实手机转向与完整辅助功能矩阵仍未在本轮验收。[本轮凭据](Evidence/0.4.0/screen-left-landscape-only-20261108/BUILD_RECEIPT.json)

---

## 0.4.0 / build62 电子屏连续转向

电子屏横竖切换改为约 320 毫秒的连续转动：同一组内容随角度调整逻辑尺寸、文字落点和艺术区构图，去掉此前的闪暗与轻缩放。默认 LCD 保留一套文字节点；共享布局按连续比例计算字号和基线，避免经过正方形时突然变大。视觉相位与媒体秒数继续独立，未新增延迟任务或播放引擎。系统减少动效或非活动场景不启动转向动画。

本轮按用户要求直接操作 **Xcode Device Hub 的原生 iOS Simulator**，查看左右转向、回正与连续反向操作；没有用网页稿代替。独立 One Tape Print Redraw QA 已更新 build62 并正常无参数启动，安装与测试产物可执行文件 SHA256 一致。实际 Xcode 构建、严格签名核验和源码检查通过（347 文件、最高 641 行），最终同轮 **15 项检查通过、0 失败／跳过**：13 项模型／绘制和 2 条模拟器 UI 流程，覆盖空库、五款播放与暂停、左右横持及冷恢复。首轮 UI 依赖的旧古铜选择行已过时，改为保留测试默认磁带后重跑通过；不删除原失败记录。

真实模拟器录像确认有连续中间角度，背景保持亮起，未见非等比字形拉伸。固定屏幕开口在斜转途中会短暂裁到边缘的曲序／时间上沿或进度条端点，终点布局完整；暂停计时原有 600 毫秒闪烁仍保留。短片来自最初的本轮原生预览，相关生产实现与最终62一致。本段仅记录模拟器，本轮未操作真机；并行轨迹渲染性能优化及其真机结果由对应窗口独立记录。减少动效系统开关、长时能耗和主观自然度仍需进一步验收。[本轮凭据](Evidence/0.4.0/screen-orientation-natural-20261108/BUILD_RECEIPT.json) · [模拟器实际切换](Evidence/0.4.0/screen-orientation-natural-20261108/lcd-continuous-turn/lcd-continuous-turn.mp4)

---

## 0.4.0 / build61 机身样式、随曲配色与固定尺寸播放键

石墨改为深色亮边按键和红色播放三角。随曲配色从当前真实封面提取主色，联动机身、按键与默认读数屏；相同封面保持同色，无封面使用默认色。封面机身同时展示实际封面纹理，其他艺术屏幕保留各自设计。机身卡片直接使用实际页面的绘制组件；重选样式会清除旧色卡覆盖，之后仍可手动选色。

播放灯只改变按键内部的亮度与图标，按压阴影也收在内部，取消原先扩展可见外圈的玻璃叠层。**正常签名 build61 已保留数据覆盖安装到 USB wired iPhone15 / iOS26.6，并在 XCTest 后无参数普通启动。** 源码检查通过（345 文件、最大641行），实际 Xcode 构建及严格签名核验通过，正常 App 没有 XCTest 插件。19项隔离模拟器模型／绘制检查通过；一条完整真机流程通过四种机身、实际播放与暂停、旧色覆盖清除和封面样式冷恢复，播放前／播放中／再暂停的按钮外圈逐像素一致、点击区域尺寸不变。

已查看实际石墨、随曲、封面播放页面和选择器。不同封面之间的换色由红、蓝合成封面的绘制检查覆盖，真机本轮未切换到另一张专辑封面；不把这些边界混作验收。原曲库索引 SHA256、两曲队列与所选曲目保留；播放位置有更新，期间正常屏幕偏好观测到从轨迹变为名称，未覆盖该选择，也不声称全部偏好字节不变。首轮透明玻璃的自动点击定位失败只修正了测试触点，最终完整流程通过，历史失败保留。这轮不代表已解决此前偶发退出，也未验收完整设备矩阵或主观音质。

[交付凭据](Evidence/0.4.0/body-style-controls-20261107/BUILD_RECEIPT.json) · [真机石墨播放](Evidence/0.4.0/body-style-controls-20261107/phone-images/controls-graphite-playing.png) · [真机机身选择器](Evidence/0.4.0/body-style-controls-20261107/phone-images/controls-adaptive-picker.png) · [普通启动主页](Evidence/0.4.0/body-style-controls-20261107/phone-normal61.png)

---

## 0.4.0 / build60 机身边框与上下边缘换色

磁带口和 LCD 的边框统一跟随所选机身换色；遮罩只保护实际磁带与显示内容。修正机身外轮廓与素材不对齐造成的上下黑色弧边，素材外侧和窗口余量也使用当前机身颜色。磁带照片自带的黑色边唇由固定机身材质层覆盖，保留内侧自然阴影；该层不进入卷轴动画。

**已保留数据覆盖安装到 USB iPhone15 / iOS26.6，最后无参数普通启动 build60。** 正常偏好文件和 Navidrome 曲库索引前后SHA256一致，恢复原岩层／干邑色／轨迹屏及两曲队列。源码检查通过（339文件、最高641行），实际正常签名构建和严格签名核验通过。13项针对性绘制／模型检查通过；正常60包上一条真机流程覆盖4种机身样式和8种配色（11个不同外观），0失败／跳过。逐项原生截图的磁带框、LCD框与上下边缘10处取样均响应换色，并已查看原生总览及白色、干邑色完整页面。

不同窗口余量和玻璃开合下的内容保护由绘制检查覆盖，实际手机视觉验收限本台iPhone15。本轮只修改材质绘制，不代表已解决此前正常使用时的退出问题。[交付凭据](Evidence/0.4.0/body-finish-edges-20261107/BUILD_RECEIPT.json) · [真机配色总览](Evidence/0.4.0/body-finish-edges-20261107/phone-finish-overview.png) · [普通启动主页](Evidence/0.4.0/body-finish-edges-20261107/phone-normal60.png)

---

## 0.4.0 / build59 切歌快转与连续卷轴相位

修复用累计时间除以当前卷径造成的历史转角重算。两轴现在各自连续积分，按同一走带线速度和各自卷径转动；带多的轴慢、带少的轴快，半程接近并在后半程交换。切歌时带量在快转期内过渡，快门残影只作用于转轴，缓和高速轮齿的频闪错觉，壳体与印字保持独立。原有真实引擎的 **14 倍快转 0.65 秒 → 停顿 0.14 秒 → 恢复播放** 顺序已核对，未另建音频引擎或用视觉时间覆盖媒体进度。

**正常签名 build59 已保留数据安装并无参数启动于 USB iPhone 15 / iOS 26.6，App 不含 XCTest 插件。** 35 项针对性模型／真实引擎／绘制检查通过；同一原生 UI 流程分别在隔离模拟器合成 PCM 与手机既有服务器曲目上通过，重复不累计。手机实际记录「切歌快转 → 切歌停顿 → 亮起」；播放时上下两轴图像都变化，暂停后磁带像素及时间保持相同。源码检查通过，现有 PlayerStore 仍为 641 行；本轮没有卸载、清数据、复制用户音频或向手机导入测试音频，正常曲库索引 SHA256 前后相同。播放操作会更新续听和诊断记录，不声称所有偏好字节不变。

交付包构建后，并行机身任务继续改了背景／边框及共享版本，这些变化已保留，独立记录源码边界，不算本轮 build59 的机身验收。正常速度使用制造商规格与本产品名义尺寸投影，未声称 Cassette 逐帧一致；主观声画感觉、长时能耗、实际减少动效开关和完整设备矩阵仍待验收。[接续说明](Docs/ONE_TAPE_REEL_MOTION_2026-11-07.md) · [本轮凭据](Evidence/0.4.0/reel-motion-sequence-20261107/BUILD_RECEIPT.json) · [真机切歌短片](Evidence/0.4.0/reel-motion-sequence-20261107/phone-reel-change59.mp4)

---

## 0.4.0 / build58 退出排查与本地诊断

抓到两次与 XCTest 清理严格对应的退出：`testmanagerd` 释放会话后，系统以 `SIGKILL(9)` 结束 App。另发现本轮复用的测试配置虽然指定新包，依赖列表仍引用旧57包，造成回装；已修正为只包含同一正常58产物的 UI 配置。新增 USB 检查脚本会拒绝不同产物、核对实际安装版本、串行运行使用该脚本的会话，并在测试结束后普通启动；直接调用旧工具不受这把锁约束。**正常手动使用时的退出尚未取得对应异常栈，不能称全部闪退已修复。**

两轮基线真机连续操作约8.6分钟未复现异常；约120秒采样内存148–169 MiB，没有观察到持续增长，但不是长时泄漏证明。32项针对性模拟器检查通过，1项需要额外私有连接文件的在线PCM检查跳过。最终在核对版本为58的 USB iPhone15 / iOS26.6 上通过播放、暂停、前后切歌、快速连续操作的原生流程，并在本机日志中核实相应58事件。测试后已无参数普通启动，检查岩层正常主页和同一进程存续，曲库索引SHA256保留。没有卸载、清数据或复制用户音频；并行自定义任务有意调整外观，不能称所有偏好字节相同。

新增本地限量操作日志和 MetricKit 系统诊断留存，不上传；操作日志不保存歌名、地址或账号信息。系统此次另有 `mediaplaybackd` 写盘资源报告，处理为 `none`，没有本应用退出归因。尚未收到真实 MetricKit 异常载荷，也未验证长时间稳定性和主观音质。本段只覆盖23:13冻结的正常58包；另一窗口随后开始的卷轴相位源码修改不属于本次验收。[排查凭据](Evidence/0.4.0/iphone-crash-audit-20261107/BUILD_RECEIPT.json) · [最终真机主页](Evidence/0.4.0/iphone-crash-audit-20261107/normal58-after-check.png)

---

## 0.4.0 / build58 六款原创模塑磁带

加入「岩层、折面、浮岛、肋骨、流线、月蚀」，入口为 **自定义 → 磁带 → 模塑**。六款使用各自的壳面、开窗、轴心、印花避让与文字落点；固定表面与卷轴分层，沿用同一播放器的转角和队列进度。新款的 One Tape 主字使用 Instrument Serif Italic。曲数与总时长读取当前完整歌单，本地与服务器歌曲统一，缺失时长显示未知，空歌单显示 `--:--`，没有沿用设计稿上的固定 `43:28` 或磁带容量 `60`。

**已保留数据覆盖安装到 USB iPhone 15 / iOS 26.6，并在测试后无参数正常启动 build58。** 手机停在无插画的「岩层」，保留原机身／屏幕选择，实际正常队列显示 **2 首、总时长 9:50**。源码检查通过（334 文件，最大 641 行），实际 Xcode 正常签名构建与严格签名核验通过，交付 App 不含 XCTest 插件。19 项针对性模型／绘制检查通过；边缘收尾后重复的 4 项绘制检查通过。正常包上两条真机 UI 流程覆盖六款选择、开合盖、冷恢复和正常曲库预览；最后仅缩略图裁边变化后，又在最终正常包复走预览、选择器和冷恢复，全部通过。重复测试不累计，早期遮罩、测试签名与运行器启动失败记录保留。

没有卸载或清理数据。正常外观有意选为岩层并关闭插画，不能称所有偏好字节不变；Navidrome 索引前后大小与修改时间一致，初次快照未记录其字节哈希，因此不声称索引前后字节相同。并行播放诊断新增日志文件，未复制用户音频。内部玻璃目前保留设计素材的灰色光照，尚未实现任意机身色的真实透射；这是二维表面与原生运动层，实播音质、长期性能与完整设备／辅助功能矩阵未在本轮验收。后续本区域继续按[模塑接续说明](Docs/ONE_TAPE_MOULDED_SHELLS_2026-11-07.md)修改。[本轮凭据](Evidence/0.4.0/moulded-shells-20261107/BUILD_RECEIPT.json) · [最终真机选择器](Evidence/0.4.0/moulded-shells-20261107/phone-final58-images/mould-strata-picker.png) · [最终真机预览](Evidence/0.4.0/moulded-shells-20261107/phone-final58-images/mould-phone-normal-cold-strata.png)

---

## 0.4.0 / build56 专辑进场、滑动反馈与详情背景

曲库先从窗口下方上移展示专辑，约 0.68 秒后顶部工具栏再从上方进入；减少动效时直接展示。上下滑动时，专辑越过中心位置触发一次较轻的机械声和系统选择触感，快速滑动限频，离页或进入后台停止反馈。选中专辑统一向后旋转展示封面，同步渐入真实封面的模糊颜色背景，再展开歌曲列表。背景覆盖整个窗口，修复详情顶部露出灰块；返回按钮保留 42 点视觉圆面并补足 44 点点击区域。

源码检查通过（322 文件、最高 641 行），正常 Xcode iOS 构建与签名核验通过。独立模拟器分阶段通过 17 项模型／音效检查和 1 条原生 UI 流程；USB iPhone 15 / iOS 26.6 同轮 **18 项通过、0 失败／跳过**。最终正常交付包另复走同一条真机 UI 流程，通过后无参数启动；重复 UI 不累计，正常包没有 XCTest 插件。已核对实际真机详情完整图，顶部颜色连续覆盖。

**build56 已保留数据覆盖安装到 USB iPhone。** 正常偏好和 Navidrome 曲库索引的 SHA256 不变，原 41 份封面缓存均保留且大小／修改时间不变；缓存未做前后字节哈希对比。单独的外观 UI 测试偏好在并行屏幕检查期间有变化，不能称所有偏好文件字节相同。触感与音色的主观强度、系统减少动效实际开关及完整辅助功能矩阵仍待上手验收。[本轮凭据](Evidence/0.4.0/library-entry-feedback-20261107/BUILD_RECEIPT.json) · [最终真机详情](Evidence/0.4.0/library-entry-feedback-20261107/phone-album-detail-final.png)

---

## 0.4.0 / build55 电子屏转向过渡

电子屏横竖切换增加约 **240 毫秒**的小过渡：80 毫秒淡出并轻缩至 98.5%，隐藏时交换逻辑尺寸与方向，再用 160 毫秒恢复。避免插值宽高时拉伸文字；保留同一内容视图及装饰时钟，不改变媒体进度。新方向会取消旧请求，离页自动取消；系统减少动效或进入后台时直接显示目标方向。

已在当前 **USB wired iPhone 15 / iOS 26.6** 签名覆盖安装 build55，最后正常无参数启动。最终真机 UI 流程通过，实际检查 LCD、流体、名称页左右转向及回正；流体和名称回正后保留严格逐像素一致断言。另有 12 项模型／绘制检查、五款播放与暂停横持及冷恢复流程通过，以及最终独立模拟器空库转向流程通过；这些结果分阶段记录，不称同一轮完整 15 项通过。实际 iPhone 录像的 LCD 中间帧确认有短淡出、换排版、淡入，未见持续旧方向或文字拉伸。

首轮新增空库测试误用“有歌曲时轻点轮换”的辅助方法，随后截图又早于异步过渡结束；均只修测试同步。一次真机名称页回正像素检查未通过，增加前后截图诊断后的重跑在未修改生产实现下通过，未声称已经证明该次差异的唯一原因。并行曲库窗口的一个未完成测试字符串曾阻止诊断构建，已由该窗口修复；全部中间日志保留。源码检查通过（交付核对为 322 文件、最大 641 行），产物签名核验通过。未卸载、清数据、导入本轮音乐或发布；正常偏好在并行设备工作期间有观测变化，不能声称所有偏好字节不变。减少动效的实际系统开关、真机实播中的转向及长时性能仍未验收。[本轮凭据](Evidence/0.4.0/lcd-orientation-transition-20261107/BUILD_RECEIPT.json) · [真机切换短片](Evidence/0.4.0/lcd-orientation-transition-20261107/phone-lcd-single-transition/phone-lcd-wide-to-tall.mp4)

---

## 0.4.0 / build54 五款屏幕横持排版与读数

将已确认的流体、雨窗、轨迹、名称、电平预览落实到原生页面。曲序、歌名、艺人和面 A/B 使用默认电子屏艺人的常规系统字体；时间保留各款的艺术字体。底部显示当前进度、播放／暂停符号和负号剩余时间，播放时按同一整数秒更新，暂停时读数与艺术画面冻结。横持时电子屏单独转向并使用窄长构图，名称支持最多三行，电平合并真实相邻频带为八列。A/B 目前按队列前后半段显示，奇数队列多的一曲归 B；没有增加物理翻面或 B 面传送机构。

源码检查通过（318 文件、最大 641 行；现有 PlayerStore 的 600 行职责评估仍适用）。实际 Xcode 构建及模拟器／iOS 产物签名核验通过，最终分两阶段通过 **38 项模型／绘制检查和 4 条真实模拟器 UI 流程**，均为 0 失败／跳过。UI 覆盖五款左右横持、空库、真实合成测试录音播放与暂停像素冻结、暂停／播放中切歌、冷启动恢复。首轮 37 通过／1 失败来自名称粒子字体在 CoreText 中回退；已修复实际字体创建，保留原有边界断言，修复后 38 项全部通过。历史失败不删除，也不与最终通过数累加。

已保留数据更新独立 **One Tape Print Redraw QA / iPhone 16 Pro / iOS 27.0** 至 build54，并核对安装产物与测试产物一致。实际 UI 图审覆盖五款左右横持及切歌后的 A 面播放／B 面暂停；不称已目视核对 B 面播放。原预览模拟器由并行播放接续窗口维护，本轮没有操作它。iOS 真机签名包已构建，但本轮未安装手机；此前 build52 的真机空库结果不能替代 build54 验收。真机旋转、播放动效、音质与能耗，以及完整辅助功能矩阵仍未验证。

沙丘、铁屑、墨水、水面继续暂缓，沙粒、示波、频谱瀑布仍不可选；LCD 与狐狸保留。没有修改或发布鸿蒙／网页工程，也没有导入用户音乐或发布商店。[本轮凭据](Evidence/0.4.0/screen-labels-orientation-20261107/BUILD_RECEIPT.json) · [模拟器最终画面](Evidence/0.4.0/screen-labels-orientation-20261107/simulator-final54.png)

---

## 0.4.0 / build53 机身按键材质与切歌绕带

左下三键随机身使用对应材质，底面、边缘、播放亮面和转向图标统一处理；原黑机身保留照片按钮，尺寸仍为 58 逻辑点。播放中短按上一首／下一首时，同一 AVPlayer 先暂停并准备目标歌曲，两卷轴以 ±14 倍速转动 0.65 秒、停转 0.14 秒，再校验当前选择并播放。暂停切歌保持暂停；连续切歌、暂停、长按、外部选择／中断和后台会取消旧恢复任务。14 倍及 0.65 秒有原版静态线索，0.14 秒停顿及按钮 RGB 是本轮体验配色，不称原版精确值。拨杆、背面来源页和 B 面仍暂缓。

源码检查通过（316 文件、最大 641 行）；实际 Xcode 正常签名模拟器构建及同轮 **56 项检查通过（54 模型／真实引擎／渲染＋2 UI，0 失败／跳过）**。已保留数据更新原 Stillroom iPhone 16 Pro 模拟器，六份原曲库／唱片／封面文件 SHA256 和机身偏好不变，实际播放及切歌后回到原曲暂停主页；未安装实体手机或发布。[本轮凭据](Evidence/0.4.0/transport-material-windup-20261107/BUILD_RECEIPT.json) · [原模拟器画面](Evidence/0.4.0/transport-material-windup-20261107/original-final53.png)

构建期间另有一组屏幕布局文件变化。后续固定快照的额外屏幕格式检查未通过，未将该快照安装到原模拟器；本次交付保留上方已通过 56 项的产物，重复播放器检查不累计。失败与并行源码边界单独保存在同目录凭据中，后续屏幕工作不算本轮已验收。

---

## 0.4.0 / build52 五款屏幕与 iPhone 空库交付

本轮将流体、雨窗、轨迹、名称、电平五款已选设计接入原生屏幕，保留 LCD 与狐狸，可选及轮换顺序为 `lcd → fluid → rain → trails → name → meters → fox`。沙丘、铁屑、墨水、水面暂缓接新稿；沙粒、示波、频谱瀑布移出当前选择。旧样式 Codable 身份保留，已存的不可用样式只在显示时回退 LCD，不迁移或覆盖旧偏好。

五款共用真实曲序／总数、曲名、艺人、时间与播放状态。加载时保留歌曲信息，空库与未知时长显示 `--:--`；名称支持长中英与 emoji。装饰相位与媒体时间分开，暂停／加载／后台时冻结，电平使用实际音频数据；没有新增播放引擎。

最终独立模拟器验收 **35 项通过、0 失败／跳过**（34 单元／渲染 + 1 UI，含七款快速轮换、Rain 左右旋转及暂停冷恢复）。此前另外三条 UI 流程已通过五款空库、实际测试录音播放暂停冻结及暂停／播放中切歌；它们与最终 35 项分阶段记录，早前失败和修复边界均保留。源码检查通过：309 文件，最高 624 行。[验收记录](Evidence/0.4.0/approved-screen-five-20261107/validation-notes.json)

**0.4.0 / 52 已签名构建、安装并正常冷启动于获授权 iPhone 15（iOS 26.6）**，真机空库 UI 检查 **1 项通过、0 失败／跳过**。已实际查看五款空库面板、完整电平播放器及测试后正常 LCD 冷启动图，未见阻塞布局；隔离测试选择未污染正常外观偏好。未卸载、清数据或导入／拷贝用户音乐。[真机图审](Evidence/0.4.0/approved-screen-five-20261107/phone-visual-review.json) · [本轮收据](Evidence/0.4.0/approved-screen-five-20261107/BUILD_RECEIPT.json)

手机真实曲库仍为空，真机音乐播放／动效与音质、真机旋转、长时性能尚未验收；最终模拟器真实旋转图仅覆盖 Rain，其余竖向覆盖包含离屏渲染。本轮未发布商店，也未修改或发布鸿蒙／网页工程。

## 0.4.0 / build51 缩小三键、切歌音效与机身黑框修正

三个圆键从 65.33 缩至 **58 逻辑点**，中心不变，视觉间隙为 10 点；点击区域在已检查的手机窗口尺寸下至少 44 点。源图原按钮尺寸与显示尺寸分开，先完整清除旧圆区，再缩放原按钮像素；按压、播放亮面及转向图标同步使用新尺寸。完整白色机身栅格核对三键实际暗色直径均为 58 点，按钮内部图像与缩放源图保持一致，详见[按钮像素核对](Evidence/0.4.0/transport-buttons-body-20261107/button-render-audit.json)。

彩色机身的矩形黑框来自磁带底图四周不透明的黑底。播放器固定磁带层现裁到与真实磁带槽／玻璃一致的圆角轮廓，露出周围机身色，保留窄边缘；原始机身和磁带 PNG 字节未改。完整播放器覆盖黑／石墨／白／鸽灰 × 开盖／关盖八种渲染，检查旧黑框位置与真实机身像素一致，并确认槽内磁带确实存在，避免空渲染误通过。[原因与几何](Evidence/0.4.0/transport-buttons-body-20261107/geometry-and-root-cause.json) · [石墨机身实际窗口](Evidence/0.4.0/transport-buttons-body-20261107/original-graphite51.png) · [白色机身](Evidence/0.4.0/transport-buttons-body-20261107/original-white51.png)

上一首／下一首短按使用同一台 CC0 磁带机实录中约 **0.158 秒**的机械接触声，增益沿用 0.65。MusicStore 先执行原有切歌／同曲重播，再由 PlayerStore 的选择修订号确认有效前台操作；空库、无效命令、同步文件失败、外部／自动切歌与恢复保持静音，长按快进／快退取消旧反馈并沿用现有绕带控制器。播放／暂停音色、音乐引擎及媒体时间没有改动。[切歌声试听](Evidence/0.4.0/transport-buttons-body-20261107/track-step-preview.wav)

源码检查通过（299 个维护代码文件、最大 624 行），正常签名的实际 Xcode Simulator 构建及签名核验通过；最终同轮 **41 项检查（39 模型／集成／渲染＋2 UI，0 失败／跳过，运行时警告为空）**通过。首轮仅测试辅助代码写入系统只读 Reduce Motion 环境键而编译失败，已移除不受支持的注入，暂停数据本身保证卷盘静止，未放宽像素断言；初始失败和最终结果均保留在[独立凭据](Evidence/0.4.0/transport-buttons-body-20261107/BUILD_RECEIPT.json)。

已保留数据更新原预览至 **build51**。实际窗口短按下一首及上一首后回到原曲，切换石墨／白色机身核对，再恢复原黑色／沙丘／城市印花／开盖外观和暂停主页；持久化外观与检查前逐字段相同，六份既有曲库／唱片文件哈希不变，五份已安装产物与测试包一致。未卸载、清数据、操作实体手机或发布；完整实体设备、路由、窗口和辅助功能矩阵仍未验收。[原预览最终画面](Evidence/0.4.0/transport-buttons-body-20261107/original-final51.png)

---

## 0.4.0 / build50 真实磁带机按键音效

按用户确认的“更像真实磁带机的机械咔嗒”，将播放／暂停的音色替换为 Joseph SARDIN 的 [BigSoundBank 0570 实录](https://bigsoundbank.com/cassette-player-play-and-pause-s0570.html)，来源页及许可页确认 CC0。播放约 0.343 秒、暂停约 0.365 秒，保留原录音的按键接触、锁扣与回弹时序，清理低频震动和底噪、柔化尖锐高频；波形峰值与 20 毫秒短时 RMS 均比 build49 低，首尾采样为零且没有削波。主观听感仍以用户试听为准。

两段无损来源摘录、原始帧区间、作者、许可与哈希放在 `Tools/AudioSources/Transport`；原始长录音只留在忽略的 Build，应用仅打包处理后的两份短 WAV 和来源清单。[处理工具](Tools/generate-transport-sounds.py)可离线确定性重建。音效服务、0.65 增益、原有播放状态确认及取消机制沿用 build49；本轮没有修改 Swift 播放引擎、界面或 B 面。

源码检查通过（299 个维护代码文件、最大 624 行；处理工具 131 行），正常签名的实际 Xcode Simulator 构建、签名核验及 **11 项针对性检查（7 音效服务＋4 实际引擎集成，0 失败／跳过，运行时警告为空）**通过。编译仍有既有 `UserDefaults` Sendable 与 AppIntents 无依赖提示，不称整个编译日志零警告。已保留数据更新原预览模拟器至 **build50**，四份已安装产物与本轮测试包一致，六份既有曲库／唱片文件哈希不变；CUA 实际点按确认加载进入播放、媒体时间推进并再次暂停。实体扬声器／耳机听感与完整路由矩阵未验收，未安装手机或发布。[独立凭据](Evidence/0.4.0/transport-audio-refinement-20261107/BUILD_RECEIPT.json) · [播放→暂停试听](Evidence/0.4.0/transport-audio-refinement-20261107/play-then-pause-preview.wav) · [原预览暂停画面](Evidence/0.4.0/transport-audio-refinement-20261107/original-final50.png)

---

## 0.4.0 / build49 播放暂停音效与按键间距

新增两段原创机械操作音效：播放锁扣约 0.82 秒、暂停释放约 0.60 秒。主页及专辑页的明确播放／暂停操作由同一音乐引擎状态确认后各触发一次；冷恢复、外部遥控／系统暂停、空库、准备取消和播放失败不制造音效。快速操作会停止旧音效，离开活跃状态会取消待处理反馈；不改音乐队列、媒体时间和分析信号。原生短音效预加载放在独立串行 actor，避免 `AVAudioPlayer.play()` 隐式同步准备阻塞界面。[生成器](Tools/generate-transport-sounds.py)与[原创来源／波形指标](Stillroom/Resources/TransportSounds/PROVENANCE.json)保留。

左下三个按钮保持原大小，中心调整为设计点 `666／734／802`，中心间隔从约 63.04 增到 68 点，留下约 2.67 点可见间隙。绘制、灯面、按压和点击区共用布局；原机身 PNG 不改，代码只清理旧按钮圆区并重排原按钮像素。黑／白机身的原始渲染核验确认三键位置、按钮脸部颜色、LCD 未受污染，旧圆区没有残留黑圈或亮弧；详见[间距审计](Evidence/0.4.0/transport-details-20261107/spacing-audit.json)。这是按用户要求稍微拉开，不称原版精确尺寸。

源码检查通过（299 个维护代码文件、最大 624 行），正常签名的实际 Xcode Simulator 构建通过。首轮 33 项通过后发现真实音效预加载的主线程警告，已移出 UI actor 并补原生完成／取消检查；最终同轮 **35 项针对性检查通过（33 模型／集成＋2 UI，0 失败／跳过，运行时警告为空）**，不累计重复执行。**build49 已保留数据更新到原预览模拟器**，安装包与最终测试包哈希一致，现有六份曲库／自制唱片文件哈希保持一致；已在原窗口播放后再次暂停。未安装实体手机或发布，真机扬声器／耳机听感及完整系统路由矩阵仍未验收。[独立凭据](Evidence/0.4.0/transport-details-20261107/BUILD_RECEIPT.json) · [原预览](Evidence/0.4.0/transport-details-20261107/original-final49.png)

B 面按用户要求暂不实施。11 月 7 日补充核实原版：至少两首时按曲数向下取半，前半 A、后半 B，奇数时 B 多一首，普通单曲默认 A。原版 iPhone 同一张五首专辑的第 2 首实测 A、第 3 首实测 B；暂停切歌跨面时没有 3D 翻转，磁带外壳的 A 印字位置保持不动。当前面也参与真实时长归一化的磁带进度计算。`PadPlayerView / DuoOpenPlayerView` 的手动翻面操作和动画连线已从局部指令确认，但未在相应设备上验收，不能据此给当前 iPhone 界面编造双击／长按步骤。本轮只更新研究记录，One Tape 仍为 build49、固定 A，未改产品源码或重装模拟器。[原版核实凭据](Evidence/0.4.0/cassette-side-audit-20261107/BUILD_RECEIPT.json) · [实测曲序／面标记](Evidence/0.4.0/cassette-side-audit-20261107/reference-side-02A-03B.png)

---

## 0.4.0 / build48 顶部控件淡入淡出

轻点磁带显示／隐藏 UI 时，顶部设置按钮改为约 0.4 秒的纯透明度过渡，取消从上方移入／移出；底栏仍用原有过渡。减少动效的无动画分支和点击范围保留。录像原始像素中，34 个可定位采样的顶部图标模板位移均为 `(0, 0)` 像素，亮度随显示／隐藏改变；完整时刻与重复帧边界见[动效核验](Evidence/0.4.0/hud-fade-20261107/motion-review.json)。

源码检查（292 个维护代码文件、最大 624 行）、正常签名的实际 Xcode Simulator 构建通过。主轮 4 项通过（3 模型＋1 UI），补充顶部设置／原生选择器取消用例隔离复跑 1 项通过，共 5 项不同检查分阶段通过。补充用例首轮未找到顶部入口的失败及当时的库菜单层级保留在[独立凭据](Evidence/0.4.0/hud-fade-20261107/BUILD_RECEIPT.json)；未修改生产或测试代码掩盖该失败，也不称单轮全部 5 项通过。

按本轮用户要求，**build48 已保留数据覆盖更新到原 Stillroom iPhone 16 Pro 模拟器**，安装版本和最终测试包可执行文件哈希一致，现有曲库／自制唱片等六份文件在更新前后哈希一致。原窗口已实际唤出 UI、进入顶部设置并返回暂停主页；未卸载、清数据或安装实体手机。此前 build47 的材质／字体工作随当前工程整合，没有在本轮重做美术或宣称其完整验收。系统减少动效端到端和实体设备矩阵仍未测试。

A／B 面说明：实体磁带两面各有录音，翻面后播放另一面。build48 当时尚未核实原版分曲规则；后续研究结论见上方 build49 补充记录。当前 One Tape 仍固定显示 A，没有接入真正的 A／B 队列划分和翻面播放；旧 Crafted 唱片双面逻辑是另一套展示，不作为 One Tape 已实现的证明。

---

## 0.4.0 / build47 沙丘、铁屑与流体屏幕

按已确认的独立预览，将三款屏幕改为整块灰阶材质画面，歌曲、艺人、曲序和真实媒体时间排在各自留白里。沙丘使用宽阔侧光坡面和衬线字，铁屑使用细密聚拢纹理和简洁无衬线字，流体使用连续折流和斜体字。横向长歌名保持单行并截断，转向后最多两行；沙丘艺人文字避开亮脊，转向后的底部加深以保持时间可读。新增五个 OFL 字体与三张优化材质图，来源及哈希随资源保存。

缓慢运动使用系统 Core Image 的平移、局部收缩和双向卷流，在异步 Canvas 绘制；视觉秒与媒体秒分开，播放暂停、页面失活和减少动效继续由现有显示时钟控制。三款保持安静的环境动效；其他屏幕沿用已有音频采样与画面逻辑。本轮为经确认的原创摄影风格美术，原版付费屏幕的完整效果仍未验证。

源码检查通过（292 个维护代码文件、最大 624 行；既有 PlayerStore 协调职责未扩展），实际 Xcode Debug Simulator 构建及正常签名核对通过。**13 项不同的针对性检查最终分阶段通过**：最终一轮 11 项模型／渲染检查，以及同一产品实现的 2 条 UI 流程；不累计重复执行，不将早期含失败项的整轮写成全绿。检查覆盖三款真实栅格动效、资源与字体、文字与旋转布局、空载、实际 PCM 播放／暂停和冷启动恢复。长中英混排与 emoji 另外保留截图人工复核，完整过程见[独立凭据](Evidence/0.4.0/screen-material-v2/BUILD_RECEIPT.json)。

已保留数据安装到原 **Stillroom iPhone 16 Pro / iOS 27.0** 模拟器，当前停在沙丘；已核对 9 个包内文件与安装产物一致，原 Application Support 的 6 个文件哈希不变。独立 QA 继续使用既有合成 PCM，无新增用户音乐。仅完成模拟器验证；真机视觉、音质、性能／能耗、系统减少动效完整流程及完整辅助功能矩阵仍未验收，未提交或发布。

[原模拟器当前画面](Evidence/0.4.0/screen-material-v2/original-simulator-final.png) · [沙丘](Evidence/0.4.0/screen-material-v2/final-frames/photo-dunes-playing-panel.png) · [铁屑](Evidence/0.4.0/screen-material-v2/final-frames/photo-iron-playing-panel.png) · [流体](Evidence/0.4.0/screen-material-v2/final-frames/photo-fluid-playing-panel.png)

---

## 0.4.0 / build46 详情页字号与底栏图标

对照已有原版截图与逻辑点边界，将播放／随机播放文字基准从 20 调至 17 点，图标独立设为 15.5 点，当前歌曲标题从 21.5 调至 20 点，底栏歌名／艺人从 15／13 调至 14／12 点。普通歌曲与封套文字保留原尺寸；按钮 48 点高度和底栏 72 点点击区保留。磁带小图标修正纵横比及描边越界，书本图标分开斜封套并闭合四边形，移除原版没有的选中圆底。真实 `SwiftUI.Path` 枚举确认 `addLines` 会丢掉此前的起点，斜封套现改用逐段 `addLine`。

源码检查（288 个维护代码文件、最大 624 行）、实际 Xcode Simulator 构建、正常签名核对及本次 **4 项针对性检查（3 模型＋1 UI，0 失败／跳过）**通过。已核对初始详情页字体和图标；播放、实际媒体时间推进、暂停与底栏返回状态正常，重复诊断执行不累计为新测试。

用户解锁后，另通过 DeviceHub 在独立 QA 常规图标启动，手动复走播放、暂停、底栏返回和静置，并核对原始 PNG。**前期仅依据工具内图像呈现作出的“暂停后缺层”判断已撤回：**最终初始／返回／静置四张 PNG 逐字节相同，后续两次手动静置采样也逐字节相同，播放文字、当前曲目和底栏区域的前景像素完整保留。图像展示差异的具体原因未确认；没有据此保留任何生产渲染／动效 workaround。手动像素核验不增加 XCTest 数量，完整证据见[本轮独立凭据](Evidence/0.4.0/detail-refinement-20261107/BUILD_RECEIPT.json)、[像素核验](Evidence/0.4.0/detail-refinement-20261107/native-unlocked/pixel-counts.json)及[暂停后画面](Evidence/0.4.0/detail-refinement-20261107/native-unlocked/paused-after-later-static.png)。只操作本窗口独立 QA，未向原预览、其他 QA 或实体手机发起安装／进程操作，未修改磁带美术、印花和屏幕动效，未提交／发布。完整辅助功能和实体设备矩阵仍未验收。

---

## 0.4.0 / build45 ¥9.90 一次性买断说明

按用户确认，将 Studio 和设置中的付费说明统一为 **人民币 9.90 元，一次性买断，不自动续费**。当前尚未开放实际购买，具体包含权益以正式商品说明为准；不承诺所有未来功能，也不发起交易或伪造恢复成功。

源码检查、实际 Xcode Simulator 构建及正常签名核对通过，本次 **5 项针对性检查通过（3 模型＋2 UI，0 失败／跳过）**，覆盖两处买断说明和复制／返回路径；没有沿用或累计 build44 的 70 项。仅使用本窗口独立 QA，未操作原预览或实体手机，未提交／发布。[买断说明截图](Evidence/0.4.0/buyout-20261107/simulator/support-01-payment-document.png) · [独立构建凭据](Evidence/0.4.0/buyout-20261107/BUILD_RECEIPT.json)

---

## 0.4.0 / build44 本地专辑封面与支持设置

本地音乐沿用现有专辑封套样式，图片来自实际文件，不联网搜索或伪造封面。自动读取音乐内嵌的 JPEG／PNG，并补读专辑艺人、曲序和碟序；首曲没有图时可使用专辑后续曲目的自动封面。导入图片先有界解码、校正方向并生成方形 JPEG；可播放音频的内嵌图损坏时会明确提示，音乐仍可导入。

本地封面可按以下方式使用：

1. **音频已内嵌封面：**照常导入，资料库封套自动显示。
2. **同目录有封面文件：**选择音乐文件夹；同目录唯一 `cover.jpg`／`folder.jpg`（也支持 PNG）且音乐属于同一专辑时，预览会建议“应用到整张专辑”，由用户确认。多专辑或多张目录图片不自动混配，可明确选择目标或跳过。
3. **音乐已经导入：**展开本地专辑，长按封套 →“设置专辑封面”→ 在“文件”中选择 JPEG／PNG → 预览并确认。新图立即更新当前专辑，冷启动保留；原音乐字节和单曲封面例外不被改写。

修复了本地专辑只取第一首图片、补图后仍命中旧缓存的问题；图片状态现在完整构造后一次发布，避免先清空再逐曲更新。回归还发现原来缺少 `sea` 曲目时也会加入示例封面缓存，已限制为实际存在的示例曲目。

设置新增**隐私政策、用户服务协议、付费说明、联系我们和问题反馈**。三份说明可在应用内离线阅读、复制全文；联系邮箱按用户提供的信息配置为 **hapy8bit@163.com**，可复制或主动撰写邮件。反馈只带用户编辑内容和应用版本，不自动附加音乐、服务器信息或日志；系统邮件不可用时提示复制邮箱回退。没有自动发送邮件，也没有对外发布协议网站。

build44 的付费说明和 Studio 显示**计划售价人民币 9.90 元**，当时购买类型仍待确认。用户随后明确为**一次性买断、不自动续费**，该方案已在后续 **build45 的说明文案**中更新；买断不承诺包含所有未来功能。build45 的构建与验证由后续凭据单独记录，不沿用下方 build44 的检查数量。当前尚未开放购买，不会发起真实付款，也不伪造恢复购买。Studio 已去除未实现绘画能力的承诺；没有接入或执行 StoreKit 交易。

源码检查通过（287 个维护代码文件、最大 624 行，PlayerStore 超过 600 行已按职责评估），实际 Xcode Simulator 构建与正常签名核对通过。同一轮 **70 项针对性检查全部通过（67 模型／集成＋3 UI，0 失败／跳过）**；随后仅改善联系按钮文字对比，最终包重复通过 2 条支持页 UI，重复项不相加。两个合成 M4A 在目录导入和手动补图后仍与原测试文件哈希一致。全部验证使用本窗口独立 QA，未操作原预览模拟器、其他窗口 QA 或实体手机，未提交／发布。详见[本轮独立凭据](Evidence/0.4.0/covers-support-20261107/BUILD_RECEIPT.json)。

[目录封面与真实两曲专辑](Evidence/0.4.0/covers-support-20261107/simulator/cover-03-local-tagged-album-with-directory-cover.png) · [手动封面冷启动保持](Evidence/0.4.0/covers-support-20261107/simulator/cover-06-replacement-survives-cold-restore.png) · [联系我们](Evidence/0.4.0/covers-support-20261107/simulator/support-02-contact-configuration-state.png) · [付费说明](Evidence/0.4.0/covers-support-20261107/simulator/support-01-payment-document.png)

---

## 0.4.0 / build43 来源、收藏与真实排序

补齐 Navidrome 的“断开此设备的连接”、事务忙碌／失败提示及仅远端目录的专辑／歌曲统计。设置与导入页改为已支持的本地音乐和 Navidrome；One Tape 导入页使用自己的产品说明，原 Stillroom 展示配置保留。常亮偏好可跨冷启动保存，旧钥匙串项删除失败会记录无密码的待清理 ID，在下次启动重试并保护当前账户。

曲目长按或通过 VoiceOver 操作可收藏／取消到此设备，Favourites 即时更新；修正本地目录先恢复时提前丢弃远端收藏的问题。Recently added 使用真实导入时间和服务端 `created`：本地专辑取最后新增曲目的导入时间，远端专辑／歌单用其创建时间，旧索引缺失日期仍保持未知，重复导入不更新日期。Recently played 从唯一播放器真正开始播放时记录歌曲顺序并持久化，再投影到专辑／歌单。这些是本产品的明确语义，未声称已逐项证明原版内部行为。另修复准备播放期间快速切歌丢失播放意图，以及首次创建导入协调器在渲染期间发布状态的问题。

本轮新建独立 **One Tape Sources Library QA43 / iPhone 16 Pro / iOS 27.0**，没有向原预览或其他窗口 QA 发安装、终止、重启命令。源码检查通过（270 个维护代码文件、最大 615 行，超过 600 行的 PlayerStore 已评估，规则与持久化位于独立文件），实际 Xcode Simulator 构建与正常签名核对通过。分阶段通过 **80 项不同的针对性检查（73 模型／集成＋7 UI）**，重复执行不相加；没有宣称某一轮全部 80 项同时通过。中间的 UI 定位、过渡等待和并行草稿编译问题及后续通过证据保存在[本轮独立凭据](Evidence/0.4.0/sources-library-20261107/BUILD_RECEIPT.json)。

原生文件选择、预览、新音频／封面保存、损坏文件独立报错、实际播放、冷启动和重复复用已分阶段验证。混合库实际为 2 本地专辑／2 曲＋50 远端专辑／501 曲／142 歌单；来源摘要只统计远端。错误地址失败保留、正常刷新和断开 UI 已通过；断开前后独立 QA 的索引、音频、封面及资料共 12 个文件哈希一致，本地两专辑冷启后仍在。403／超时／取消等失败由模型注入验证，不把它们写成真实网络中断的 UI 验收。美术、磁带和屏幕更新由并行窗口负责，本轮保留其文件并仅更新工程引用。未安装产品到实体手机、提交或发布；历史偶发退出、真机音质／能耗和完整系统媒体控制矩阵仍未验收。

[新音频与封面实际保存](Evidence/0.4.0/sources-library-20261107/simulator/00-native-initial-save-result.png) · [本地专辑真实播放](Evidence/0.4.0/sources-library-20261107/simulator/03-local-real-playing-album.png) · [远端曲目收藏入口](Evidence/0.4.0/sources-library-20261107/simulator/interaction-add-favourite-action.png) · [最近播放冷启顺序](Evidence/0.4.0/sources-library-20261107/simulator/history-recently-played-remote-first-after-relaunch.png) · [断开后本地专辑](Evidence/0.4.0/sources-library-20261107/simulator/11-local-album-survives-disconnect.png)

---

## 0.4.0 / 屏幕初稿 v1

继续核对原版安装包的中英文说明后，将非 LCD 屏幕改成“清晰播放信息＋独立艺术区”。顶部保留曲序、A 面、播放状态、已播放及剩余时间；底部保留歌名、艺人和进度。艺术区独立裁切，模糊与混合不再覆盖信息。默认 LCD 的原有布局保留；名称页直接以沙粒组成歌名和艺人，底部不重复两行文字。长名称使用可读字号与省略截断，空白信息有回退文案，旋转时按交换后的逻辑尺寸重新布局。

流体由银色金属改为浅底黑色液体；示波、电平及频谱继续使用真实 PCM 分析，缺少采样或暂停时不伪造声波。材质页暂停时保持视觉相位，返回前台不会把后台耗时累加到媒体时间；狐狸沿用独立的安静待机／睡眠状态。墨水、雨窗、轨迹和频谱瀑布保留为“扩展”分组。原有五款印花、古铜、艺术字和并行音乐来源功能保留。

**这是本产品的设计初稿。** 原版文案能够确认各款的材质和声音响应方向，但仍不能证明付费屏幕是否同时叠加完整播放读数；本版的信息框架、布局、配色和具体动画属于设计判断，不称已看过或完整复原原版。原始说明、截图及证据边界见[核对记录](Evidence/0.4.0/screen-draft-v1/reference-observations.json)。检查与最终安装以[本轮凭据](Evidence/0.4.0/screen-draft-v1/BUILD_RECEIPT.json)为准，不沿用下方旧版测试数量。

实际 Xcode Simulator 构建、常规模拟器签名及源码检查通过（284 个维护代码文件，最大 615 行，无超过 800 行；现有 PlayerStore 的责任评估记录在凭据中，本轮屏幕职责均置于独立组件）。整合阶段 28 项断言检查通过后，截图复核仍发现空库名称页漏绘：将缓存状态在 View.body 中建立刷新依赖，再由 Canvas 使用不可变文字快照，修复了没有声音更新时不重绘的问题。最终源码另通过 **8 项渲染／布局＋2 项真实截图 UI 检查**，验证暂停、有曲、空库和冷启动粒子字；两轮不合计为 38 项，也不称最终重跑全部 28 项。

**0.4.0/build43 已保留数据更新到原 Stillroom iPhone 16 Pro 模拟器**，停在古铜＋流体、已有曲目暂停的主页。最终更新前后六份现有目录／自制唱片文件哈希一致；测试合成音频只在独立 QA，未复制到原模拟器或手机。未安装产品到实体手机或发布；真机音质、帧率、能耗及完整辅助功能矩阵未验收。

[14 款初稿预览](Evidence/0.4.0/screen-draft-v1/preview.html) · [流体实际播放](Evidence/0.4.0/screen-draft-v1/simulator/draft-fluid-playing-panel.png) · [名称暂停恢复](Evidence/0.4.0/screen-draft-v1/simulator/draft-name-restored-lettering-panel.png) · [空库名称修正](Evidence/0.4.0/screen-draft-v1/simulator/draft-name-empty-restored-lettering-panel.png) · [原模拟器最终画面](Evidence/0.4.0/screen-draft-v1/simulator/original-installed-fluid-paused.png)。

---

## 0.4.0 / build42 古铜磁带与艺术字

五款印花重绘完成后，新增“磁带 → 模塑 → 古铜”：灰金色拉丝壳、楔形开窗、凹凸压边、黑色螺丝、白色红弧大卷盘与小齿轮均由原生组件绘制。两卷盘角度和带量沿用现有播放器状态，没有新增动画时钟。印花与品牌文字使用同一孔洞遮罩，避开开窗、卷盘和螺丝。“One Tape”改用复古斜体 **Racing Sans One**；完整 OFL 许可与[来源记录](Stillroom/Resources/Fonts/RacingSansOne-SOURCES.json)已随包保留。

本轮实际查看了当前连接的 iPhone 15 原版页面；点击古铜仍进入 Studio ¥88 解锁页，因此只确认了 **288×195 原版缩略图**，未看到完整古铜材质与动画。本版据小图重建，补充的金属细节、转动和玻璃效果属于本产品实现，不称原版完整复原。五款印花仍是用户授权补细节的再创作。屏幕相关 14 份文件与此前快照一致；未修改或新增屏幕效果。[观察边界](Evidence/0.4.0/build42/reference/bronze-observations.json)及[范围审计](Evidence/0.4.0/build42/bronze-scope-audit.json)可复核。

源码检查通过（258 个维护代码文件、最大 598 行），实际 Xcode Simulator 构建与同轮 **19 项针对性测试通过**（13 项领域／渲染、6 项 UI，0 失败／跳过），覆盖字体注册、两卷盘绘制响应、带量、镂空、五款印花、开合盖及冷启动外观恢复。随后以正常模拟器签名重建，最终包再通过 5 项渲染／领域检查与 1 项古铜 UI 闭环；这 6 项是重复覆盖，不与 19 相加。首次共享模拟器测试为 18 通过／1 失败，失败 AX 已离开古铜空库场景；转到独立 QA 后未改手势源码而整轮通过。有曲古铜实播、原版完整光影及产品真机音质／帧率仍未验收。最终包保留数据覆盖更新到原 Stillroom iPhone 16 Pro 模拟器，现有目录索引、自制唱片记录及四张封面共六份文件在最终更新前后哈希一致；未安装到实体手机或发布。

[原模拟器最终古铜与艺术字](Evidence/0.4.0/build42/bronze-simulator/original-installed-bronze-art-font-final.png) · [野生印花与古铜](Evidence/0.4.0/build42/bronze-simulator/final-package/bronze-05-wild-open-mask.png) · [合盖画面](Evidence/0.4.0/build42/bronze-simulator/final-package/bronze-03-brand-closed.png) · [本轮独立凭据](Evidence/0.4.0/build42/BRONZE_BUILD_RECEIPT.json)。下方交互阶段测试与印花重绘阶段分别保留，不合计为本轮全量回归。

---

## 0.4.0 / build42 搜索、磁带展开与播放灯

通过USB重新录制原版交互后，补齐搜索从右展开、顶部功能左退及关闭时反向返回；磁带先转起，在中下部展示，再上移停稳，最后淡入返回键、播放控件与曲目。播放键跟随同一权威播放状态持续呈暖银色，按住略暗，暂停约0.2秒退回深色。列表淡入结束后才启用触摸，避免快速点击被吞；动画与媒体时间分离，离页／减少动效／资料失效均有取消或收束路径。

修正封面取色的指针借用、异常采样率转换及旧歌词导入的异步下标风险。最新09:14退出有明确外部调试force-quit证据，与桌面图标启动发生交错；后续自动化改在独立QA模拟器执行，本窗口不再向原机发起自动化重启；并行测试也应使用独立QA以避免主动终止预览进程。十轮同一PID连续交互通过，原窗口另连续观察约9.1分钟未换进程。更新后09:40:15的另一次退出也明确来自testmanagerd主动终止，随后已正常图标打开；具体测试客户端未建立归因。不能用这些记录解释所有历史间歇退出。

源码检查通过（258个维护代码文件、最大598行），实际Xcode Simulator构建及签名核对通过。交互阶段106项针对性测试通过（97模型＋9 UI，0失败／跳过）；最终整合包保留另一窗口刚加入的艺术改动，并重复通过搜索与真实播放两条UI流程。[完整凭据](Evidence/0.4.0/build42/BUILD_RECEIPT.json)明确区分两阶段证据。原模拟器覆盖更新，未卸载、清库或重置正常外观；未安装产品到实体手机，未发布。

[11秒交互录像（静音，独立QA）](Evidence/0.4.0/build41/interaction-preview.mp4) · [原版USB交互记录](Evidence/0.4.0/build41/reference-observations.json) · [稳定性检查](Evidence/0.4.0/build41/stability-run.json)。交互阶段本身不设计印花和动态屏幕；艺术交付及独立测试见本页对应小节。

---

## 0.4.0 / 印花重绘 v1

五款印花分别依据原始小图的画法重绘，并补充细节。每款为 **1536×1024 透明 PNG**，使用内置 ImageGen；这是参考风格的再创作，并非找回原版付费高清资源。

| 印花 | 保留的画法与构图 | 大图检查预览 |
| --- | --- | --- |
| 小狗 | 稀疏随手线描、长鼻垂耳、低伏长身与摆尾 | [小狗](output/imagegen/print-redraw-v1/dog-review-white.png) |
| 毛毛虫 | 极简圆节与细脚、小蝴蝶、大面积留白 | [毛毛虫](output/imagegen/print-redraw-v1/caterpillar-review-white.png) |
| 跷跷板 | 左大右小人物相向坐姿、细线三角支点 | [跷跷板](output/imagegen/print-redraw-v1/seesaw-review-white.png) |
| 城市 | 巴黎屋顶版画、黑猫、铁塔与圆顶、窗瓦排线 | [城市](output/imagegen/print-redraw-v1/city-review-white.png) |
| 野生 | 植物蚀刻、对望栖鸟、花藤叶脉与细线羽毛 | [野生](output/imagegen/print-redraw-v1/wild-review-white.png) |

五款独立生成，城市、野生另各做一次背景分离修正。原始生成 PNG 按字节复制进带 `RecreatedInkV1` 后缀的新资源集；原版小图、上一版提取线稿及旧稿保留。[素材清单与每款精确提示词](output/imagegen/print-redraw-v1/manifest.json)记录输入、输出、哈希和工具来源。白底 PNG 仅作检查；实际素材保留透明通道。人物比例、线条粗细、建筑植物细节属于补绘，未称精确放大或原版复原。

播放器以墨色深度与透明度共同形成印花，再由已有磁带孔洞遮罩裁切；浅色窗户不会被模板着色变成实心墨块。选择列表继续展示原版小图作为参考，页面明确标注重绘与再创作。屏幕及播放状态没有在本轮修改；绘画、网点与画纸导入仍未实现。

本轮使用独立的 **One Tape Print Redraw QA / iPhone 16 Pro / iOS 27.0** 模拟器，避免与原模拟器上的其他交互测试互相影响。源码检查通过（255 个维护代码文件，最大 598 行），实际 Xcode Simulator 构建通过。修正透明遮罩后，同轮 10 项回归通过（5 项领域／渲染、5 项 UI）；随后仅调整野生留边，最终源码另通过 2 项针对性测试（五款实际渲染覆盖率、五款应用／移除／冷启动闭环），不把重复执行相加。五款实际画面已检查，手动预览停在野生印花。完整结果与中间问题见 [印花重绘凭据](Evidence/0.4.0/print-redraw-v1/BUILD_RECEIPT.json)。未安装产品到实体手机或发布。

[小狗实际效果](Evidence/0.4.0/print-redraw-v1/simulator/print-applied-dog.png) · [毛毛虫](Evidence/0.4.0/print-redraw-v1/simulator/print-applied-caterpillar.png) · [跷跷板](Evidence/0.4.0/print-redraw-v1/simulator/print-applied-seesaw.png) · [城市](Evidence/0.4.0/print-redraw-v1/simulator/print-applied-city.png) · [野生](Evidence/0.4.0/print-redraw-v1/simulator/print-applied-wild.png)。

---

## 历史：0.4.0 / build40 印花页面与缩略图放大

本轮只调整印花。页面使用实际看过的原版缩略图，保留画画、网点、获取画纸、导入和“无／小狗／毛毛虫／跷跷板／城市／野生”选择；调整半透明底板和画纸按钮图标，移除原版印花页未出现的表面效果、玻璃、品牌开关及额外 Studio 链接。绘画与画纸相关功能尚未实现，点击会明确提示。

五款大印花改为从原版 **288×192 PNG 缩略图**提取可见墨迹，再按磁带已有逻辑几何放大；不再使用此前自行绘制的大图。提取只移除纸底、深灰模板与孔洞，不补画未知笔画，也没有生成式增强。选择印花时隐藏品牌文字，避免旧设置造成叠字；选择“无”恢复品牌印字。[提取脚本](Tools/extract-observed-doodle-ink.swift)与[来源及分辨率限制](Evidence/observed-doodle-ink-provenance.json)保留了源图哈希。

这属于缩略图放大，**没有取得原版付费大图**；城市与野生的细节受源分辨率限制，模板边缘一像素的保守清理也可能损失邻近细线。墨色与光照合成沿用既有播放器，不代表已确认原版完整材质效果。屏幕页、动态绘制、轮换及旧屏幕偏好行为保持原样，本轮未实施屏幕还原。

源码检查通过（252 个维护代码文件，最大 598 行）；实际 Xcode Simulator 构建与同轮 9 项针对性 XCTest 通过（4 项领域、5 项 UI，0 失败／跳过），七张印花截图已检查。详见 [build40 凭据](Evidence/0.4.0/build40/BUILD_RECEIPT.json)。产品只在原 Stillroom iPhone 16 Pro 模拟器验证；未安装到实体手机、购买、上传或发布。

[印花页面](Evidence/0.4.0/build40/simulator/print-01-observed-page.png) · [小狗放大](Evidence/0.4.0/build40/simulator/print-applied-dog.png) · [城市放大](Evidence/0.4.0/build40/simulator/print-applied-city.png) · [野生放大](Evidence/0.4.0/build40/simulator/print-applied-wild.png)。

---

## 历史：0.4.0 / build39 真实曲库与动态屏幕

One Tape 的播放器、资料库和自定义外观现共用 `PlayerStore` 的同一套真实播放状态。本地导入沿用现有暂存与事务服务；Navidrome 支持连接、专辑／歌单、封面、HTTP 流播放、刷新和断开，密码保存在 Keychain，目录与本地文件索引分开。此轮使用用户授权的公开 demo，实际快照为50张专辑、501首歌、142个歌单；不把服务器目录当作自带测试音乐。

音乐库采用竖向磁带盒陈列，展开封套显示封面和曲目。点选歌曲留在列表，底部可回到实体播放器，再回资料库保留已展开专辑、搜索与位置。LCD 使用真实曲名、艺人、队列、时长和进度；轻点可轮换屏幕。短按切歌，上一曲在播放位置超过3秒时重头；长按左右键以六倍速度定位当前歌曲，松手按此前状态继续或保持暂停。

原版在关闭方向锁后仍保持竖向机身，仅内部 LCD 和按键转向。One Tape 按此方式实现左右旋转，重排显示区域而非裁切旋转后的横版文字。磁带卷盘以独立视觉相位旋转、卷带面积随真实队列进度变化，不用视觉时钟修改媒体时间。

根据用户最新方向，5款印花参考主题重新绘制；动态屏幕作为 One Tape 的原创艺术创作，覆盖流体、水面、铁屑、沙丘、墨水、雨窗、轨迹等。自定义页直接预览同一块屏幕。示波、电平和频谱瀑布取自唯一 AVPlayer 的 PCM tap；其他艺术运动可使用独立环境相位。暂停／不支持采样时不会伪造音频波形。系统减少动效、失活与取消路径保留。

最终源码、构建、测试与实际屏幕证据正在收敛，以 [build39凭据](Evidence/0.4.0/build39/BUILD_RECEIPT.json) 为准。原版 USB 真机用于交互研究；One Tape 在原 Stillroom iPhone 16 Pro 模拟器中展示。没有购买原版付费内容、安装产品到实体手机、上传或发布；完整真机音质、能耗和辅助功能矩阵仍待验收。

---

## 历史：0.4.0 / build38 主页滑动玻璃盖

主页磁带区域支持上滑合上玻璃、下滑打开。盖层跟随手指移动，松手按预测位置吸附；合上后磁带机械部分变暗、虚化，One Tape 印字保持清晰。轻点仍显示／隐藏浮动导航，LCD 和播放按键维持原有独立操作。

本轮先通过 USB 助手实际操作原版 Cassette Player，确认开合方向和遮罩表现，再核对其局部逻辑点几何、8点拖动阈值、越界1/6阻尼与0.5秒／0.9阻尼弹簧。经典磁带使用6张对应的玻璃下材质，图片固定，移动的是圆角遮罩及盖边；其他磁带继续使用原生近似。

开合与自定义“玻璃”选项共用一个外观状态，只在松手后保存。保留build37的JSON键以兼容已有设置；拖动中不写偏好，不生成媒体进度。离开页面、应用失活或被面板遮挡时取消拖动；提供辅助功能开合操作，并遵循减少动效设置。

源码检查通过：206个维护代码文件、最大498行；实际Xcode Simulator构建及最终同轮15项针对性测试通过（11项领域、4项UI，0失败／跳过）。检查和中间问题修复过程见本轮 [构建凭据](Evidence/0.4.0/build38/BUILD_RECEIPT.json)。

[开盖](Evidence/0.4.0/build38/simulator/01-glass-open.png) · [合盖](Evidence/0.4.0/build38/simulator/02-glass-closed.png) · [拖动中途](Evidence/0.4.0/build38/simulator/07-glass-mid-drag.png) · [深色磁带合盖](Evidence/0.4.0/build38/simulator/06-graphite-glass-closed.png)。中途原始帧来自此前已通过15项测试的同轮实现，后续仅补取消清理与非经典深色处理；未用它证明后两项。

原版手机仅用于研究，产品已更新到原 Stillroom iPhone 16 Pro 模拟器，保留正常外观设置并展示合盖主页。本轮不改变音乐导入、音频引擎、Navidrome或其他平台；非经典素材与完整真机手感仍待后续验收。

---

# One Tape · iOS

当前为 **0.4.0 / build37**。本轮修正用户指出的三处问题：Studio背景不再重复同一张白磁带，而改为原版不同封套的错位拼贴、模糊和渐隐；主播放器及预览中的品牌文字改为原生 One Tape；右下角真正打开“磁带／印花／机身／屏幕”自定义浮层。

自定义面板依照本轮 USB 实际采集：底部导航保持可用，磁带页固定大预览、下面网格滚动；机身和屏幕页随内容缩短面板。支持5款磁带、无图案＋5款印花、4种机身＋8色、10种屏幕，玻璃与品牌印字独立开关。选择即时用于同一主页；关闭、重开和冷启动后保留外观。Studio关闭回原分类；纯装饰预览不接收触摸，避免缩放旋转后的大布局区域挡住上方按钮。

外观通过独立Preferences Service存储，不读取或改写音乐索引；无法解码的旧外观记录不会被默认值覆盖，失败会提示。动态屏幕以20fps独立视觉时钟绘制，减少动效或后台时停更，空态媒体时间始终0:00。页面接数据与事件，Domain保存纯外观值和导航规则，Store协调状态，Services管理偏好和系统常亮；所有代码继续满足800行上限。

**检查：**source-check通过，201个维护代码文件、最大498物理行；实际Xcode Debug Simulator构建通过。**7项领域＋2项自定义UI＋3项空库UI，共12项针对性测试分轮通过**。冻结源码整轮为11通过／1失败，来源入口单例随后以同一产品源码重跑通过；没有称整轮全绿。完整过程与中间命中／开启动画问题见[构建凭据](Evidence/0.4.0/build37/BUILD_RECEIPT.json)。

[One Tape主页面](Evidence/0.4.0/build37/simulator/01-one-tape-brand-print.png) · [磁带面板](Evidence/0.4.0/build37/simulator/02-customize-tape.png) · [印花](Evidence/0.4.0/build37/simulator/03-customize-print.png) · [机身](Evidence/0.4.0/build37/simulator/04-customize-body.png) · [屏幕](Evidence/0.4.0/build37/simulator/05-customize-screen.png) · [修正的Studio背景](Evidence/0.4.0/build37/simulator/07-corrected-studio-montage.png)。本轮更新仍在原Stillroom iPhone16Pro模拟器；手机只用于观察原版，没有安装One Tape build37。

**素材边界：**经典大图、网格缩略图和Studio封套使用已取得的原版参考素材；非经典磁带大图、5款印花大图与非LCD动态屏幕为原生近似，未称完整1:1。原包的对应大图属于缺失ODR，当前归档只有ExternalLink而无可取资源包地址。[资源来源](Evidence/0.4.0/build37/reference-assets-provenance.json)与[缩略图边界](Evidence/0.4.0/build37/customization-thumbnail-provenance.json)明确记录。原版旧品牌Print图层已退出产品资源。模塑系列、绘画编辑、网点照片、画纸导入和真实购买暂未接入；本地音乐、Navidrome与有音乐时的样式仍按后续阶段进行。

---

## 0.4.0 / build36 空库首版历史

当前为 **0.4.0 / build36，默认空库复刻首版**。参考 Cassette Player（Jerry Munyoka Nkongolo）1.0.3/build9：通过 USB 独立 XCTest 助手实际操作已安装的原版，跳过开屏引导，采集空播放器、浮动导航、空音乐库、搜索、设置和 Studio 入口。原始二进制、逆向模型、设备与签名授权材料保留在工程外的私有研究目录。

默认主页已切换为黑色机身、白色占位磁带与 LCD。空态的“01/01”是设备显示占位，实际曲目数为零；按播放、上一首、下一首不会启动旧示例音频或产生媒体进度。LCD 每约0.6秒独立切换明暗，减少动效时恒亮；浮动导航约0.4秒进入，闲置约6秒收起。按键采用约0.12秒深色叠层反馈，长按任务在释放、后台和离开时取消。

空库支持“专辑／播放列表”、来源与排序菜单、展开搜索、无结果、关闭搜索收起键盘，以及底部返回播放器。设置采用 medium/large 原生 sheet；屏幕常亮通过独立 Service 管理，并在场景失活或离开时恢复原系统策略。Studio、组件缩略图和其余设置是本轮次要页面近似，外观定制、购买、遥控器、环境感应和主屏幕组件尚未接入。

本轮选定原版默认材质图层用于本机参考预览，布局、状态、LCD、按钮和导航为新写原生代码；材质的原名称与哈希见[来源清单](Evidence/0.4.0/build36/reference-assets.json)，后续可独立替换为 One Tape 的差异化素材。Geist 字体保留完整 OFL 许可与[字体来源](Stillroom/Resources/Fonts/FONT-SOURCES.json)。当前不是完整产品或完整1:1验收。

**验证：**`node Tools/check-source.cjs`通过，185个维护代码文件、最大498物理行；实际 Xcode Debug Simulator 构建通过，最终同一轮 **4项领域测试＋3项新界面流程＋1项旧库冷启动回归，共8项通过、0失败／跳过**。中间3个新界面用例曾因父容器覆盖按钮 AX 标识失败，修正后重跑通过；没有把失败轮次称为全绿。[构建与验证凭据](Evidence/0.4.0/build36/BUILD_RECEIPT.json)区分原版真机研究、模拟器复刻和未验证能力。

已在原 **Stillroom iPhone 16 Pro / iOS27.0** 模拟器覆盖更新并打开默认空库页，未卸载或清数据。未将 One Tape 安装到实体手机，未发布。已有曲库、导入服务和播放器源码保留；默认预览不读取／改写旧索引，也不创建旧 PlayerStore。显式启动参数 `--legacy-stillroom` 可进入旧界面，旧 UI 回归用例已追加此参数。

[默认空库](Evidence/0.4.0/build36/simulator/01-one-tape-default-empty.png) · [浮动导航](Evidence/0.4.0/build36/simulator/03-one-tape-floating-navigation.png) · [空音乐库](Evidence/0.4.0/build36/simulator/04-one-tape-empty-albums.png) · [搜索](Evidence/0.4.0/build36/simulator/05-one-tape-library-search.png)。

接下来先逆向原版有音乐时的页面与实际播放，再接入现有安全本地导入与统一播放引擎；之后实现 Navidrome 连接、曲库元数据、封面与流播放，最后进行 One Tape 差异化。音乐来源面板已留本地／Navidrome入口，当前点击会说明下一阶段接入，不会伪造导入成功或服务器连接。

代码按页面编排、State状态协调、Domain规则、Services系统接口、材质资源拆分；组件只接数据与事件。继续遵守800行上限（超过600行评估拆分）、秒与逻辑点的单位边界、安全区／窗口适配、辅助功能、减少动效、异步失败提示与取消释放、签名本地配置、不得损坏或覆盖旧索引等约束。完整横屏／大字号／VoiceOver矩阵、真机帧率／触感／音质，以及原版完整动画参数尚未验收。[原版观察与实施计划](Evidence/0.4.0/build36/reference-observations.json)。

---

# Stillroom · iOS

独立 SwiftUI 原生音乐项目。本轮 **0.3.2 / build35** 根据用户红框截图修正资料库顶部的悬浮控件与搜索状态，仅修改iOS资料库呈现。

## 0.3.2 / build35 参考截图顶部修正

用户补充的两张红框图明确显示：内容从顶部控件后方滚过，没有横贯整行的深色底板或分隔线；左右圆钮和中央分段各自带浅色半透明材质，图标和分段文字为黑色。本轮据此移除build34的连续底板，将顶部控件叠在滚动视口上，内容起始留白按实际控件高度与安全区计算；左侧图标显示当前网格／列表。

搜索展开时同时收起左菜单和分段，长胶囊从左侧原菜单位置铺开，右侧保留独立圆形×；关闭清除查询、收起键盘并原位恢复三组控件。过渡仅变换材质背景，保留控件的布局和辅助功能边界，沿用本地与系统减少动效。既有真实专辑、网格／列表过渡、底部选中态和唯一播放状态保留。

源码检查、Debug与最终Release构建、严格签名和冻结包核对通过。9项模型和4项相关界面用例分轮通过；中间整轮因XCTest将悬浮圆钮自动点击选在透明包围框角落，记录为12通过、1失败。最终用例改为当前控件边界内的实际圆心触摸，验证滚动、搜索、关闭、布局切换和暂停导航后通过，没有把中间整轮称为全绿。模拟器已更新并恢复正常真实资料库；本轮真机覆盖安装因CoreDevice4016未完成，最后确认的手机版本仍为build34。

验证、截图与安装边界见 [build35凭据](Evidence/0.3.2/build35/BUILD_RECEIPT.json)。仅按红框修正顶部，没有复制原图的购买层、定价或三列封面展示。大字体完整矩阵、真机触感、原版精确过渡时序仍待验证。

[滚动后的悬浮控件](Evidence/0.3.2/build35/simulator/02-floating-controls-over-scrolled-covers.png) · [整行搜索与圆形关闭](Evidence/0.3.2/build35/simulator/03-full-row-search-and-close.png)。

## 0.3.2 / build34 资料库交互（已由build35修正顶部）

顶部栏增加连续毛玻璃底色并覆盖状态栏安全区，专辑向上滚动时保持固定。右侧搜索在同一行向左展开，临时替换“专辑／歌单”分段；取消后原位恢复。左上菜单切换网格／列表增加0.3秒淡入、轻缩放过渡；底部仅当前页面有高亮胶囊，其他图标降低亮度，中央组在未选中时去掉底色。动效同时遵循应用内与系统减少动效设置。

**源码检查、Debug和最终Release构建、严格签名及冻结包核对通过。9项资料库模型检查、4项相关界面用例分轮通过。**正常动效用例使用9首真实目录，实际检查滚动前后位置、同行搜索、相同专辑的布局切换与三处唯一选中；旧资料库流程覆盖冷启动、搜索／取消、真实播放队列与暂停。本轮不沿用build33的191项测试数量作为build34全量重跑证据。

模拟器已恢复到无fixture参数的真实资料库。**iPhone已覆盖安装0.3.2/build34并核对版本，保留原数据**；本轮未复验真机视觉、声音与帧率，大字体和完整窗口矩阵仍待检查。

[21秒正常动效预览](Evidence/0.3.2/build34/library-search-layout-motion.mp4) · [上滑后的顶部背景](Evidence/0.3.2/build34/simulator/02-scrolled-header-background.png) · [同行展开搜索](Evidence/0.3.2/build34/simulator/03-search-expanded-in-header-row.png) · [最终构建凭据](Evidence/0.3.2/build34/BUILD_RECEIPT.json)。

## 0.3.2 / build33 参考播放页

唱片向左裁切，封面标签扩大到盘面直径的49%；右侧使用黑色底座、银色直管与黑色唱头。封面氛围背景从上方灰绿过渡到底部深色。收起时保留三枚实体键；轻点唱片下方空白后，切换为顶部工具、底部资料库／当前播放／队列胶囊，以及左下外观和右下更多入口。外观编辑在同一页面底部展开，保留上方唱片；通用材质、专辑专属材质和背景保存分别生效。

按钮功能先由原版观察和逆向确认：正常唱片单击播放／暂停，左右拖动按原版的global预测位移与100点严格阈值切歌；顶部左键请求横竖屏切换；外观页太阳键循环唱臂灯的关闭、红、蓝、紫。播放器视图选择移至“更多”，保留歌词、封套与记忆、制作唱片、本地导入等已有功能。修正放大的唱片延伸到首次入场返回区域后，返回点击穿透触发播放的问题。

新安装默认使用烟纹盘面与封面氛围；已有背景、专属样式及用户音乐继续保留。需要切换到本轮效果时，在唱机轻点下方空白→左下外观，选择烟纹与第一枚封面氛围背景。右下太阳按钮控制唱臂灯，单独的自定义背景颜色入口在外观“更多”中。

**边界：**原版购买层和价格未实现；主唱机唱臂拖拽的取消／释放规则、纵向历史、精确过渡时序仍待验证。材质、金属和灯晕是本地绘制，灯晕大小、宽屏布局及6秒工具闲置时长是本地适配，未宣称完整1:1。原参考截图中的Mac窗口边框、顶部工具条没有放入应用。

最终源码检查为 **170个维护代码文件、最多498行、零超限**；**191项单元／集成与8项相关界面用例分轮通过**。最后一轮191+2项全部通过，未把分轮结果描述为同一轮199项。Release严格签名及冻结包校验通过，**0.3.2/build33已覆盖安装到iPhone16Pro并核对版本、成功前台启动**。手机当前使用中，镜像未连接，因此最终真机视觉与手感仍待体验，不以模拟器替代验收。

本轮最终构建、检查、截图与设备安装结果以 [build33凭据](Evidence/0.3.2/build33/BUILD_RECEIPT.json) 为准。[收起播放页](Evidence/0.3.2/build33/simulator/01-reference-player.png) · [展开工具](Evidence/0.3.2/build33/simulator/02-reference-player.png) · [页面内外观](Evidence/0.3.2/build33/simulator/03-reference-player.png)。

## 0.3.2 / build32 默认机械唱臂

原来大块灰色底板与黑方盖改为紧凑的分层圆形金属法兰、细刻度和开放轴承框；配重增加滚花及刻度边，管体以连续高光表现圆柱截面，唱头改为收尖镂空结构、金属连接环、指托和小型唱针。造型参考真实唱臂的机械分层，采用本地UI比例原创绘制；[研究来源](Evidence/0.3.2/build32/design-references.json)里的官网照片仅供观察，没有进入App资源。

默认是**拉丝银**。`OrbitArmAppearance`独立提供金属与点缀色，绘制组件只读该纯值，不访问偏好、购买状态或播放器。[三种材质研究（停放状态）](Evidence/0.3.2/build32/tonearm-material-study-parked.png)为同一源组件在macOS离屏渲染的预览，**不是iPhone截图**；黑／金尚无用户选择入口，也没有持久化、价格、商品或解锁流程。后续可在上层接唱臂外观与付费能力，当前不能称已支持用户换肤或付费。

画布120×440、转轴(70,50)、唱头中心(68,391)及既有角度输入不变。底座、停臂架和升降杆固定，承架、配重、管体和唱头随轴旋转；首次入场继续使用外置拖动／辅助功能层，普通唱机的唱臂仍为纯绘制。没有增加播放时钟、随机纹理或逐帧位图生成。

源码检查通过：160个维护代码文件，最多498行。Debug／Release实际构建、严格签名、冻结包树哈希核对通过，9份原曲保留原SHA256。**181项单元／集成＋3项相关UI，共184项在同一轮通过，0失败／跳过**；包含真实拖动落针、播放交接、主唱机播放／暂停、三种主视图及样式入口。已查看最终浅色主唱机、深色入场停放／播放画面，管体、黑色唱头和铜色点缀在两种背景中可辨。

**0.3.2/build32已保留数据覆盖安装到iPhone16 Pro，实机安装版本已核实。**手机正在使用，镜像不可用，因此没有宣称完成build32的真机视觉复验，也未强制重连或切换手机当前页面。最终专用模拟器已退出旧测试fixture，重新进入九张真实专辑的默认目录并保持暂停。未卸载、清数据或更改用户音乐。

[实际主唱机（模拟器）](Evidence/0.3.2/build32/simulator/01-main-silver-paused.png) · [深色入场播放（模拟器）](Evidence/0.3.2/build32/simulator/03-opening-dark-playing.png) · [构建凭据](Evidence/0.3.2/build32/BUILD_RECEIPT.json) · [签名包](Artifacts/Stillroom-0.3.2-32-tonearm.app.zip)。极限姿态／完整窗口字号矩阵、真机观感、帧率与能耗仍未验收；不把源码静态边界审查或离屏预览当作这些设备证据。

## 0.3.2 / build31 九张真实专辑

在原有Cylinders、Divider之外，增加Chris Zabriskie的Angie's Sunday Service（2022）、Soft Rock Champion（2022）、Abandon Babylon（2021）、I Made This While You Were Asleep（2020）、Music from Neptune Flux（2016）、Reappear（2012）、Direct to Video（2015）。专辑、封面、艺人、年份和曲目均核对[艺人官网](https://chriszabriskie.com/music/)；每张本机收录1首完整原曲，**不是完整专辑曲目表**。Reappear选第4首，其余新增专辑选首曲。没有复制同一封套凑九层，也没有给旧音频重贴新专辑身份。

7份新M4A与7张原封面来自官网，下载音频直接复制，未裁切或转码；真实解码时长和SHA256在[来源清单](Evidence/0.3.2/build31/album-sources.json)中记录。旧两首及其ID／封面／音频原字节不变。音乐采用[艺人公布的CC BY4.0授权](https://chriszabriskie.com/use/)，详情、设置和随包文本同步提供署名。原封面仅按各自原作品引用作本机预览，保留官网列出的作者；音乐授权不等于另行验证了封面的广泛再分发授权。

源码检查通过：159个维护代码文件，最大498行。最终产品源码已完成Debug／Release实际构建、严格签名、冻结ZIP与提取包树哈希核对，包内9份原曲均按来源SHA256核验。181项单元／集成、2项既有真实专辑UI，以及1项新增九张专辑UI**分轮通过**；不把有失败的中间整轮报告称为全绿。新增流程以物理窗口触点验证双向拖动、两端新专辑身份、选择不自动播放、明确落针后真实播放、返回暂停，以及普通资料库搜索和详情。投影／退场的AX边界会超出裁切画面，因此测试固定真实窗口坐标并检查交互结果；完整VoiceOver／投影辅助功能框验收仍未完成。

**0.3.2/build31已保留数据覆盖安装到iPhone16 Pro，实机版本已核实。**已实际观察九层封套、连续向上浏览、选中Direct to Video、翻开到唱机、明确落针播放及返回暂停。最后一次预览启动进入首次选片页；随后手机被使用，镜像断开，没有再次重连或改动用户当前操作。未卸载、清数据或改动用户音乐。

[九层选片截图（最终模拟器）](Evidence/0.3.2/build31/simulator/01-nine-real-sleeves.png) · [新增唱片（实机）](Evidence/0.3.2/build31/iphone/03-direct-to-video-ready-paused.png) · [明确播放（实机）](Evidence/0.3.2/build31/iphone/04-explicit-needle-playing.png) · [最终凭据](Evidence/0.3.2/build31/BUILD_RECEIPT.json) · [签名预览包](Artifacts/Stillroom-0.3.2-31-nine-albums.app.zip)。未测真机音质、帧率、能耗、完整横屏／字号矩阵；本轮不宣称动画已完全1:1验收。

## 0.3.2 / build30 首次选片入场动画

按用户确认，只修改首次“选片入场”，没有把堆叠动画换成日常首页。先重新观察原版实际选择过程，再以 REA／LLVM 交叉核实的首次入场 renderer 为依据重做；[原版几何证据及未恢复项](Evidence/0.3.2/build30/original-intro-geometry.json) 明确区分普通 CoverFlow 与入场逻辑。

- 封面与书脊分别绕同一行基准投影，采用原版零高度布局、局部镜像与 +90° 图像方向、顶部铰链、透视1，以及按位置计算的角度／封面尺寸／行距。镜像在侧视瞬间换向，不把整张方卡从中心倾斜或在可见面中途压扁。
- 选择后，邻片向上下退开并模糊；选中层延迟0.24秒再以弹簧翻正。竖屏正面目标尺寸为容器宽减80；封套按恢复的距离及0.4秒曲线向左退出，露出原先被遮住的唱片，再进入现有唱机。翻开本身不启动音频。
- 手机倾斜使用首样本校准、相对重力折返、0.015发布阈值与1/60秒请求间隔；仅在前台未选片且未减少动效时采样。返回、背景、重选和退出均取消旧任务。两张真实专辑仍为两个真实身份，没有复制成九张或加入宣传徽章。

源码检查通过：158个维护代码文件，最多498行。最终源码通过 **181项单元／集成＋6项相关界面测试，共187项，0失败／跳过**；覆盖几何、重力映射、延迟取消、实际投影封面点按身份、正常唱臂拖动及共享引擎播放、减少动效、返回／重选／跳过，以及真实专辑资料和播放。Debug／Release实际构建、严格签名、冻结包与提取包树哈希核验均通过。

**0.3.2/build30已保留数据覆盖安装到iPhone16 Pro，实机版本、两张真实封套的翻开／露盘／唱机落点及返回已核对，手机停在未播放的首次选片页。**[最终模拟器原速动画](Evidence/0.3.2/build30/simulator/opening-animation.mp4) 是最终录屏4.3–8.8秒的节选，未加速或插帧；[完整录屏](Evidence/0.3.2/build30/simulator/opening-final.mp4)、[分阶段画面](Evidence/0.3.2/build30/simulator/opening-final-contact-sheet.jpg)、[实机选片入口](Evidence/0.3.2/build30/iphone/04-final-sleeve-list.png)和[构建凭据](Evidence/0.3.2/build30/BUILD_RECEIPT.json)可复核。

实际两项数据居中的起点、目标纵向位置、横屏容器适配、书脊材质和既有滚动惯性仍是明确的本地适配；原版完整唱片放大／唱臂几何、最初约541毫秒的逐帧证据、真机倾斜手感／帧率／能耗与完整横屏／字号矩阵未验收。不宣称整段1:1或测得60fps。音乐和封面来源及许可边界沿用下方build29记录。

## 0.3.2 / build29 真实参考专辑

默认资料库现在展示 Chris Zabriskie 正式发行的两张专辑，各收录1首完整原曲：

- [Cylinders（2014）](https://chriszabriskie.com/cylinders/)：Cylinder One，实际可播放时长约2:56。
- [Divider（2011）](https://chriszabriskie.com/divider/)：Heliograph，实际可播放时长约5:39。

原封面、艺人、专辑、曲名与音频保持对应；没有把旧WAV重新包装成真实专辑。M4A从艺人官网实际播放器使用的地址获取，未裁切或转码，资源测试核对完整SHA256与真实解码时长。详情明确“本机收录这张专辑的1首原曲”，不把选曲数冒充原专辑完整曲目数。歌曲采用艺人公开的 [CC BY4.0许可](https://chriszabriskie.com/use/)，详情、设置与随包文档提供署名及来源。封面按原作品引用作本机界面预览，保留Cylinders封面作者Patrick Scott Bell署名；音乐许可不代表已经验证封面再分发许可，详见[来源记录](Evidence/0.3.2/build29/album-sources.json)。

默认首页和入场使用新参考专辑及现有用户导入。sea/window/night保留原ID与原音频，只用于解析既有书签、自制唱片、收藏和显式旧测试fixture；不会把已有记忆换绑成新曲目。播放器仍是唯一PlayerStore/AVAudioPlayer，没有新增网络播放引擎或第二播放状态。

源码检查通过：152个维护代码文件，最大498行。build28同一轮通过168项单元／集成和7项相关UI；修正年份显示后，最终build29重新完成Debug/Release构建及2项真实专辑UI验证，未宣称175项全部在最后源码上再跑一轮。最终Release严格签名、冻结ZIP及包树哈希核验通过，**0.3.2/build29已覆盖安装到iPhone16 Pro，实机版本和启动已确认**。最终手机已核对真实首页及Divider资料，暂停并留在首页；两首真机播放进度在音频与引擎相同的build28已核对，最终29也通过两首模拟器真实播放流程。未卸载、清数据或改动用户音乐。

[最终凭据](Evidence/0.3.2/build29/BUILD_RECEIPT.json) · [真机首页](Evidence/0.3.2/build29/iphone/01-real-album-home.png) · [Cylinders详情](Evidence/0.3.2/build29/simulator/02-cylinders-detail.png) · [Divider详情](Evidence/0.3.2/build29/simulator/03-divider-detail.png) · [原曲唱机](Evidence/0.3.2/build29/simulator/05-heliograph-turntable.png)。真实音质、触感、帧率与完整设备矩阵仍待用户体验确认。

## 0.3.2 / build27 常驻首页预览（历史演示素材）

- **资料库是正常首页。**顶部菜单、专辑／歌单分段和搜索，底部浮动导航胶囊使用已观察的原版结构；首页可以在日常使用中随时返回，不再藏在“更多”菜单。新预览启动默认资料库；这属于当前产品选择，原版启动默认页和上次页面恢复策略仍未核实。
- **内容来自本机。**真实专辑提供网格／列表、专辑名或艺人排序、喜欢歌曲筛选、搜索和详情。搜索命中歌曲时仍能看到真实所属专辑；打开详情不会开始播放或替换队列。歌单分段明确标为“智能歌单”，只投影现有喜欢、本机导入和原创试听；没有创建虚构用户歌单或添加历史。
- **三个平级主入口。**资料库、原有唱机和真实播放队列共用 PlayerStore。选曲或明确按播放才提交音频操作；单纯导航保持当前歌曲、队列和播放／暂停状态。轮盘／圆盘网格保留为播放器的显示偏好，与主导航分开。
- **首次体验独立。**跳过未播放的首次体验进入资料库；实际落针后继续进入唱机，底部仍可返回首页。从唱机明确重看后，退出恢复正常主界面。

原版资料库参考为 `Evidence/md-vinyl-reference/runtime/02-empty-library.png` 和 `03-library-layout-menu.png`。原版连接库为空，因此填充后的普通封套架、详情和选片运动没有实机1:1证据；本版真实内容与详情为 Stillroom 的原生适配。构建、测试及部署边界见 [build27 凭据](Evidence/0.3.2/build27/BUILD_RECEIPT.json)。

最终 build27 源码检查通过：147 个维护代码文件，最多469行。Release严格签名及冻结包哈希校验通过；160项单元／集成与3项不同首页界面流程在 build27 分轮通过，另5项入场／Orbit回归在 build26 通过，未宣称最终包一次性跑过全部8项界面测试。新增首页的真实播放、队列不被浏览替换、暂停不被导航重启，以及搜索／列表网格／智能歌单均已覆盖。

[首页](Evidence/0.3.2/build27/simulator/01-library-home.png) · [专辑详情](Evidence/0.3.2/build27/simulator/02-album-detail.png) · [唱机](Evidence/0.3.2/build27/simulator/03-player.png) · [队列](Evidence/0.3.2/build27/simulator/04-queue.png)。模拟器已重新启动并停在正常资料库首页。**最终build27真机覆盖安装仍待连接恢复**：本轮尝试返回CoreDevice4016，Mac锁屏也阻止了交互式置前；冻结签名包已就绪。图片和自动化结果不等于真机手感／音质验收。

## 0.3.2 / build24 选片入场预览（历史）

- **连续的选片过程。**使用现有真实专辑和三首原创试听，竖向浏览透视封套；从被点击封套的位置翻正，封套移开露出同一张唱片，唱片进入主唱机并出现唱臂。原包已核实的弹簧和局部阶段调度用于编排；完整铰链／透视与落针阈值尚未逐项还原，集中作为预览参数，不宣称精确 1:1。
- **选片不等于播放。**翻封套只持有视觉选择，不改当前歌曲、队列、自制唱片会话或书签。实际拖动唱臂或点击“放下唱臂”后，延后 0.5 秒提交给唯一 `PlayerStore → AudioPlayback` 引擎；旋转和“正在播放”由匹配曲目的真实引擎状态驱动。
- **可取消，也可重看。**返回、重选、退出与后台会作废未执行的播放票据；仍在激活而未响起的准备也会取消。首轮体验可以跳过，完成后保存独立标记；主界面“更多 → 选片入场”可以再次打开，保留既有曲库、外观、自制唱片和记忆资料。
- **原生适配。**视窗尺寸和安全区决定封套、唱片及唱臂位置，支持减少动效与 VoiceOver。沿用 Stillroom 自己的封面、音乐和绘制组件，没有把原版品牌或商业音乐资源放入应用。

[选片首屏](Evidence/0.3.2/simulator/01-opening-sleeves.png) · [唱片入场](Evidence/0.3.2/simulator/02-record-ready.png) · [实际拖臂播放](Evidence/0.3.2/simulator/03-needle-playing.png) · [本轮构建与验证凭据](Evidence/0.3.2/BUILD_RECEIPT.json)。最终构建、安装和验证结果以本轮凭据为准，历史 build 19 和本轮中间包不能代替最终包验收。精确原版透视、物理手感、音质和帧率仍待用户评估。

最终 build24 的源码检查、Release 严格签名和冻结包校验通过；同一轮通过 **151 项单元／集成测试与 5 项相关界面测试**。已在 iOS 模拟器完成封面选中、翻封套、露盘、拖臂真实播放和进入主唱机的人工查看，并停在封套首屏。[实际操作录屏](Evidence/0.3.2/simulator/record-opening-build24-preview.mp4)。本轮原包研究依据与未还原参数见 [证据边界](Evidence/0.3.2/onboarding-reference.json)。

**最终 build24 真机安装待连接恢复。**iPhone 在安装前断开，CoreDevice 返回4016，镜像重连超时；不能把中间 build23 记录当作最终安装或真机验收。冻结签名包已就绪，保留现有身份与数据，无卸载或清数据。

## 0.3.1 统一唱机（历史 build 19）

- **同一台唱机。**左侧越界大唱盘、右上固定底座与活动唱臂、下方歌曲资料和实体胶囊控制。背景覆盖安全区；新安装默认银灰与黑胶，已有首页、材质、背景和贴纸偏好保留。
- **唱片身份贯穿播放。**自制唱片使用自己的唱芯标题、照片、印色与 A/B 面，不借用源专辑封面。同一面跨源专辑续曲不换盘；翻面才更换物理面。唱针进度由真实媒体时长派生。
- **封套是播放的延伸。**从唱机打开封套正反面、双面曲序与逐曲记忆；记忆目标固定到所选歌曲。编辑保存并落针后回到主唱机，结束时仍在唱机上翻面、重听或收藏。暂停时返回唱机保持暂停，不突然响起音乐。
- **独立的视觉运动。**唱片图样只在封面、印刷、材质或面变化时生成位图，由 Core Animation 旋转。手拨累计视觉角与本次媒体定位分开；松手保留角度，换歌、隐藏及取消会丢弃旧手势。没有增加音频实例或媒体时钟。
- **制作与存档边界。**输入标题或寄语时制作按钮让开；预览保持正方形。重复编辑同一唱片使用新的呈现请求；自动完成记录按制作版本去重，编辑后的新版可以重新记录听完。收藏成功状态来自磁盘提交。

源码检查通过：131 个维护代码文件，最大 469 行。136 项单元／集成测试与 5 项不同界面用例分轮通过；最后完整双面闭环使用最终应用源码重新执行成功，不把分轮结果描述为一次性全部通过。中间自动化遮挡误点与定位到精确终点的失败记录保留，修正后验证了真实曲尾、记忆、收藏与冷启动恢复。

Release 构建与严格签名校验通过。**0.3.1 / build19 已从冻结签名包覆盖安装到 iPhone16 Pro，并确认版本与启动成功。**真机已查看普通唱片、银灰背景、安全区、落针播放、暂停与封套入口；保留原数据，未卸载、清数据或做手机备份。签名已续期至 2026-11-03 14:01:19（北京时间）。

[最终构建凭据](Evidence/0.3.1/BUILD_RECEIPT.json) · [真机主唱机](Evidence/0.3.1/iphone/installed-turntable.png) · [模拟器闭环与记忆恢复](Evidence/0.3.1/simulator/crafted-11b-cold-restored-sleeve-and-memory.png) · [签名预览包](Artifacts/Stillroom-0.3.1-19.app.zip)。真实音质、帧率、长时间耗电与完整设备矩阵尚未验收。封套聚焦时仍有 SwiftUI 尺寸运行警告待定位；本轮已修复可见的按钮遮挡，并通过受影响输入流程。以下旧版页面与证据仅属于各自历史包。

## 0.3.0 历史检查与安装边界

**113 项单元／集成测试、5 项不同界面用例分轮通过。**完整流程轮次 `tests-final.log` 通过 111 项单元／集成和全部 5 项界面用例（3 项 CraftedJourney、1 项照片流程、1 项 Orbit 回归）；补充真实 A／B 面媒体时间派生针位后，`tests-needle-final.log` 再次通过全部 113 项单元／集成和 1 项普通动效界面用例。更新后的原生照片选择器流程另在 `photos-ui-native-selector.log` 重跑通过。重复运行不增加不同用例数量，未把结果描述为最终源码一次性执行 118 项。

最终源码已实际重建 **0.3.0 / build 18 Release**，严格签名校验通过，签名包及哈希已冻结；源码检查为 **121 个维护代码文件、最多 469 行、零超限**。用户重新连接并解锁 iPhone 后，已从冻结 ZIP 提取同一签名包，核对完整包树哈希，再覆盖安装到 iPhone16 Pro；**实机版本0.3.0/build18已确认，前台启动命令成功**。此前 CoreDevice4016仅为已解决的连接失败记录。保留原数据，未卸载、清数据或做手机备份；真机视觉、声音和帧率仍待体验验证。原0.2.0安装记录保留在后方历史小节。

交付包：[Stillroom-0.3.0-18.app.zip](Artifacts/Stillroom-0.3.0-18.app.zip) · [本轮固定构建凭据](Evidence/0.3.0/BUILD_RECEIPT.json) · [模拟器流程画面目录](Evidence/0.3.0/simulator)。画面包括[封套制作](Evidence/0.3.0/simulator/crafted-03-sleeve-making.png)、[真实播放](Evidence/0.3.0/simulator/crafted-04-a-side-playing.png)、[结束与收藏](Evidence/0.3.0/simulator/crafted-10-collected-sleeve.png)、[歌曲记忆](Evidence/0.3.0/simulator/crafted-08-saved-song-memory.png)和[照片封套](Evidence/0.3.0/simulator/craft-photo-04-confirmed-photo-sleeve.png)。照片流程已在专用模拟器完成原生照片选取、取消裁切、缩放／平移／重置、确认保存、仅保存唱片和冷启动恢复；这些画面与自动化结果不作为真机视觉或音质验收。

**0.3.0 历史签名限制：该历史包描述文件于 2026-10-27 13:45:14（北京时间）到期。**该轮自动续签曾受 Xcode“No Accounts”阻止；当前0.3.1已在用户登录原账户后续签，见上方记录。构建和模拟器通过不能证明到期后的 iPhone 可启动，也不能证明真机帧率、音质或完整产品验收。

## 0.3.0 自制唱片与歌曲记忆

入口位于首页顶栏「我的唱片」，「更多」中也保留制作与收藏入口。制作和歌曲记忆共用现有曲库、TrackID 与同一个 AVAudioPlayer；没有新建第二个播放时钟或修改原音乐文件。

- **从选歌开始。**搜索本机曲库，将歌曲放入 A／B 面；同一张唱片内歌曲不重复，最多 40 首，A 面至少 1 首，B 面可以留空。曲序支持原生拖动、前后移动、跨面移动和移出。总时长只使用已知真实时长，缺失时明确显示待读取，不按曲数编造。暂不可用的原曲保留身份并提示修复，不用试听曲替代。
- **制作封套。**深夜桌面配合纸质封套、细折脊、静态印刷纹理和原生字体。提供字印、照片、拼色三种构图，夜墨、钴蓝、朱砂、苔绿四种印色；名字最多 60 字，背面寄语最多 600 字。正反翻看时在封套转到侧边后切换可见面，减少动效保留直接切换；编辑文字可明确收起键盘，滚动和翻看封套会结束输入。
- **选照片与裁切。**自制封套与歌曲记忆使用系统照片选择器，读取授权的 HEIC／JPEG／PNG 内容；受 16 MB／一亿像素上限约束，校正方向并采样后进入方形裁切。可拖动、缩放和重置，确认结果以实际保存的 JPEG 解码预览；重新编码不携带原照片的位置元数据。原照片保持不动；取消裁切不替换当前照片，iCloud 读取和裁切未完成时禁止保存／退出，避免把未确认照片当成已保存。
- **草稿与制作完成分开。**可存为草稿继续修改，也可只保存已完成唱片或「制作完成并落针」。保存成功后才更新唱片柜及开始播放；退出时可保存草稿、放弃本次修改或继续制作，失败保留当前编辑。唱片柜区分工作台草稿、桌边唱片和已收藏唱片，数量与内容全部来自真实存档。
- **播放自己编排的双面。**从 A 面按实际曲序开始；A 面结束后，可按设置收针等待亲手翻面，或连续播放 B 面。播放、暂停、定位、锁屏控制和切歌继续作用于权威音频引擎。暂停与冷启动恢复保持静音，系统中断沿用原引擎按此前播放意图与系统恢复提示处理的规则。播放页面持有当次制作版的曲序、封套和图片；编辑后的新版明确留到下次从 A 面开始使用，旧完成结果不会标到新版本上。
- **结束、记忆与收藏。**自然播放到末尾或用户主动收针后进入结束页，可以留下可选的一句话／歌曲记忆，再收进唱片柜。只有每首歌的真实解码完成回调全部到达，才记录该制作版的完整听完日期；手动跳过或主动结束不会制造完整收听记录。收藏是独立的用户动作，重复点击不会重复创建唱片。
- **歌曲记忆。**可从首页或自制唱片曲目行打开，打开时固定 TrackID，之后切歌不会把保存内容写给另一首歌。每条记忆可写最多 2000 字、选配照片、填写自己选择的日期；日期默认留空，不把导入时间、播放时间或照片定位冒充生活记忆。可继续编辑已保存条目，保存成功后更新，取消或失败保留原内容。
- **本机资料保存。**唱片、记忆和图片存入独立本地存档，写入经过校验并原子替换；新图片先成为不可变资产，再提交引用。损坏存档保留原字节并阻止覆盖，失败不抹掉旧唱片、记忆或原音乐。冷启动恢复真实资料和暂停状态；当前没有账号、云同步或社交发布。

本版沿用 0.2.0 的本地音频与导入能力；独立 Navidrome／OpenSubsonic 登录、远程流媒体与服务器音频离线下载仍未移植到 iOS。本轮没有扩展 NAS 功能，也未改鸿蒙或网页工程。照片裁切的专用模拟器验证不等于真实 iCloud 网络、真机多指、完整照片格式组合、物理音频／中断或性能验收。

## 0.2.0 历史构建与安装

**0.2.0 / build 15 曾覆盖安装到 iPhone，并确认版本与启动成功**，将 Orbit 三首页、唱片个性化和本地导入整理流程接入 iOS。以下构建、安装和截图只归属于该历史包，不能证明 0.3.0 安装。

最终 build 15 的 Release 实际构建、签名校验通过；iOS 模拟器实际 **78 项单元／集成测试＋1 项 Orbit 界面流程，共 79 项通过**，包含 12 项新导入预览测试。同一界面流程的截图重跑不另计用例。最终模拟器画面已检查，停放唱臂完整留在画面内。此前 build 13 在 iPhone 核对过三首页、切视图保留同一当前歌曲及队列自然结束，属于中间包证据；最终 build 15 已安装并启动，但镜像受手机麦克风使用影响，尚未完成其真机可视交互复验。未测真机声音、帧率与完整设备矩阵，也不宣称整款 1:1 验收完成。下文 0.1.x 的安装、测试数量与性能数字保留为各自历史记录。

**0.2.0 历史签名有效期：该包内描述文件于 2026-10-27 13:45:14（北京时间，UTC 05:45:14）到期。**该轮自动续签返回“No Accounts”，未延长有效期；到期后需在 Xcode 登录原开发者账户，再按同一身份重新签名并覆盖安装。无需卸载、清数据或做手机备份。Apple 对此类开发预览的定期重新配置说明见 [Developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account/)。

历史交付包：[Stillroom-0.2.0-15.app.zip](Artifacts/Stillroom-0.2.0-15.app.zip) · [该轮固定构建凭据](Evidence/0.2.0/BUILD_RECEIPT.json) · [该轮最终模拟器唱盘画面](Evidence/0.2.0/simulator-build15-turntable.png)。安装、测试、签名有效期与未验证项分别记录，不把模拟器画面当作最终真机视觉验收。

## 0.2.0 播放与导入基础（0.3.0 沿用）

- 首页为「滚轮」「唱片列表」「黑胶唱盘」三个平级视图，切换共用当前歌曲、队列、播放开关和真实媒体时间。滚轮与圆盘网格的重复槽位对应真实专辑，不复制业务歌曲；列表选曲原地播放，播放盘显示小唱臂与进度波纹。首页从专辑建立连续队列，专辑详情保持单专辑范围；暂停归臂，同专辑相邻自然续曲与跨专辑换盘分别处理，旧动画不能回写播放状态。
- 顶栏的视图按钮切换三首页；「更多」提供歌词、播放队列、添加音乐、资料库和设置。滚轮／列表的「更多」还提供唱片外观，唱盘顶栏有独立调色盘入口。资料库、歌词、队列与设置作为功能页面打开，旧 0.1.x 的三标签／纸片首页仍留在历史源码与记录中，不作为当前首页说明。
- 唱片外观提供树脂、黑胶、封面、双色 4 种材质；背景为默认浅绿、白色、黑色、淡紫、浅蓝 5 种全局设置。材质／配色／贴纸支持全局默认与专辑覆盖，专辑可恢复跟随全局；背景切歌保留。4 种原创贴纸最多放置 12 枚，可拖移、调整大小／旋转、删除，独立草稿完成才保存，取消不改原样式。样式与用户歌词、封面分开保存。
- 导入先选文件、读取解析、预览，再确认保存；可只选音乐、同批选择音乐与 LRC／TXT、JPEG／PNG，或读取已授权文件夹及子目录。预览可继续添加文件，将多次选择合为一批；单批最多 30 项，原文件预算 1 GB，单个音频限 512 MB、歌词 1 MB、封面 16 MB。系统 Files 授权原件保持不动，导入不自动播放。
- SHA-256 按内容识别本地重复；唯一旧歌曲复用 TrackID，同批相同音频只提交一份，别名带入的新歌词／封面继续关联。同名多候选、多个旧身份和同类资料冲突须明确选择或跳过，不能根据近似标题猜目标。坏配套单独失败，其他有效音乐可保存；停止保留已提交内容，清理未提交暂存。独立曲库索引原子替换，UUID 提升日志在成功验证曲库后核对，只清理日志明确指向的未提交副本，不做整批任务恢复或手机备份。
- 歌词支持严格 UTF-8、带 BOM 的 UTF-16 LE／BE、LRC 多时间戳与同时间多行、offset 和纯文本。原稿与规范播放版独立保存，预览使用实际播放时间；正 offset 提前，旧歌词解析保持历史兼容。补充单首资料固定到打开时的 TrackID，切歌不会改写另一首；保存失败保留旧值。GBK／GB18030、语言手选和高级时间编辑尚未接入。
- JPEG／PNG 文件经内容校验、方向校正、采样和自动居中方形裁切后保存 JPEG；预览后明确选单曲或整张专辑，专辑替换保留单曲例外。独立手工覆盖层保留原始自动资料，同 ID 更新刷新唱芯、专辑封套与系统媒体信息；不修改源文件。该版没有照片选择器和可拖移缩放的裁切页；0.3.0 新增的照片裁切仅用于自制封套和歌曲记忆，原歌曲／专辑封面替换仍沿用这里的文件导入流程。完整标签编辑、稳定 AlbumID 和改名迁移仍未接入。
- 冷启动恢复可用歌曲、队列、模式、媒体位置、首页视图与样式，保持暂停，用户主动播放才准备同一音频引擎并定位。所有视图继续由 PlayerStore 与唯一 AVAudioPlayer 驱动，视觉相位不产生媒体进度；系统媒体控制、后台音频、减少动效与辅助功能保留，完整设备中断矩阵及长期运行仍须专项验证。

本版 **仍是本地 AVAudioPlayer 播放器**。通过 iPhone「文件」已经授权的 iCloud、网盘或 NAS／共享目录复制进来，沿用原有安全作用域与文件协调路径；本轮没有用真实服务器来源完成授权、下载或断线验证。独立 Navidrome／OpenSubsonic 登录、远程流媒体、服务器音频离线队列与缓存管理没有移植到 iOS，不能把 Files 复制或鸿蒙已有的服务器能力称为本版已接入。

本轮原版参照来自已观察的 Orbit 页面和状态；其本地 LRC 页面受 Pro 入口限制，未检查到歌词编辑、封面替换、导入冲突或结果页面。新增整理流程依据 Stillroom 的本地音乐契约实现，不宣称这些页面已与 Orbit 逐页复刻。

## 0.1.x 历史体验与迭代（不代表当前首页）

- 听音：点击封套在当前画面展开唱片廊，横向拨动可浏览有透视层次的专辑封面；点击黑胶，唱片从封套滑出，再移到唱盘位置放稳，最后唱臂落针。上滑时仍分解为翻转飘散、边缘逐渐消蚀的纸片，下方音乐首页随滚动进入，反向拖动还原。
- 播放器：偏左上方的大黑胶、右侧唱臂与封面色深背景，底部只留歌曲信息和播放/前后切歌。左侧唱片边缘按参考构图有意出画，中心标签和唱臂保持可见。轻点唱片播放/暂停，左右轻扫切歌，下滑回到封套，拖动唱臂松手后定位；长按提供专辑、收藏和播放模式等操作。同一权威音频状态驱动所有页面，本版先不显示歌词或进度条。
- 唱片库：专辑、歌曲、搜索、专辑详情，以及持久化的喜欢收藏。
- 曲序：顺序播放、随机、列表循环、单曲循环；顺序播放到末尾停止，手动切歌可首尾切换。
- 导入：从系统文件选择器导入本地音频；复制到应用内，读取可用的名称、艺术家、专辑、时长和内嵌封面。曲库索引原子写入；损坏索引保持原样，停止覆盖保存。
- 歌词数据：UTF-8 LRC/TXT 的导入与解析保留，最大 1 MB；播放器中的展示、切换和歌词导入入口暂时收起，现有数据不删除。设置中的导入仍会关联到打开选择器时的歌曲。
- 系统音频：后台音频模式、Now Playing 信息、锁屏/控制中心播放和暂停、前后切歌及定位；耳机断开暂停，系统音频中断后遵循恢复提示。
- 动效：进入时抽片落针，切歌时抬针、换片、再落针，背景和歌名同步过渡；减少动效使用淡入淡出。唱片标签由 Core Animation 旋转，与媒体时间分离；隐藏的首页装饰暂停刷新。

底部使用 SwiftUI 原生 TabView / Tab，图标、选中态、材质和尺寸由 iOS 系统绘制。三个标签页共用同一套系统标签；唱片廊和纯唱片场景覆盖时隐藏并禁用底层内容，返回后恢复原标签与滚动状态。iOS 26+ 关闭滚动时的自动缩小，避免切换后的外观跳变。迷你播放器放在唱片库与设置页的安全区内，独立于系统底栏；听音页隐藏。曲库搜索固定在顶部，页面导航、搜索和滚动状态继续由 TabView 保留。系统媒体接入参考 [Becoming a now playable app](https://developer.apple.com/documentation/mediaplayer/becoming-a-now-playable-app)。

0.1.1 的上滑参考用户提供的 8.9 秒录屏：前景翻转、飘散和消蚀与下方内容入场重叠。使用原有封面和黑胶内容，未复制录屏中的文字、打字机或其他应用界面。Canvas 共享一张按歌曲与尺寸缓存的图像，各片运动和侵蚀边界由同一滚动坐标计算；没有随机逐帧状态或另一个播放时钟。减少动效时保留交叉淡入淡出。实际效果与手感仍以用户体验确认为准。

0.1.2 将转场落点改为卡片式音乐首页：暖白的当前歌曲卡、横向专辑架、喜欢收藏、随机挑一首、收藏预览和本地导入入口。歌曲、封面、收藏数量都来自现有曲库；空收藏使用引导文案，不构造历史、推荐或统计。首页按钮接入同一个 PlayerStore，专辑可打开详情并播放，随机入口会在有其他歌曲时避开当前曲目。

保留 0.1.1 的纸片运动、消蚀边缘与交叠时序。首页和转场共用一个纵向 ScrollView：从唱片开始的手势落在首页顶部，之后可自由浏览较长内容；反向跨过转场区间时吸附还原。减少动效保留淡入淡出。用户已认可上一版消散效果；本版卡片视觉与实际手感仍待用户体验确认。

0.1.3 重做沉浸播放器：唱片直径同时受窗口宽度和剩余展示高度约束，完整圆周、唱臂、阴影与下方信息留出空间，移除原来展示区域的裁切。模糊封面色彩贯穿整页，控件使用同一背景；进度条为细线与小圆点，但仍保留 44 点操作区域、拖动松手定位和辅助功能增减操作。大字体或短窗口可纵向浏览，避免把唱片压入控制区。播放器先不显示歌词，原有歌词数据和底层解析保留。

0.1.4 统一底部导航，并将参考图的折页与机械仪表转译为音乐组件：折页显示本地歌曲、本地专辑、喜欢和内置试听的真实数量；机械卡显示当前歌曲、实际播放比例、时间与播放入口。沿用纸片消散、专辑架、收藏和沉浸播放器。

本地导入面板提供多选音频和递归选择文件夹，使用系统安全作用域和文件协调读取 Files 提供者的文件，再复制到应用私有目录。显示逐文件进度，可在当前文件完成后停止；结果分开报告新增、相同内容和失败文件及原因。SHA-256 按块读取，相同文件改名后仍会跳过；标签不同导致字节不同的文件不视为同一首。旧索引中的音频会补算指纹，读取时不覆盖索引，下次成功保存时一同保存。曲库新增“我的导入”筛选，空库明确引导导入，试听曲不会计为用户导入。

用户当前选择优先完成本地导入。本版未接入私人服务器。可先通过 iPhone「文件」连接已有共享文件夹，再复制音乐到 App；未来如需独立音乐服务器，优先评估 Navidrome / OpenSubsonic 的专辑、搜索、封面与音频接口，凭据使用 Keychain，并独立设计远程播放与离线下载。现有 AVAudioPlayer 播放本地文件，不能直接宣称已经支持远程流媒体。

导入设计依据：[Apple 文件目录访问与协调](https://developer.apple.com/documentation/uikit/providing-access-to-directories)、[iPhone 文件连接服务器](https://support.apple.com/en-my/guide/iphone/iphe9aff429a/ios)。后续服务器参考：[Navidrome API 兼容范围](https://www.navidrome.org/docs/developers/subsonic-api/)。网盘、iCloud、NAS 的实际授权、下载及断线行为仍需在用户设备使用相应来源验证。

0.1.5 按用户要求移除 0.1.4 的自定义 RoomDock，恢复苹果原生底栏。没有手绘系统底栏背景、选中胶囊或按钮布局；也不再动态启用系统 bottom accessory，迷你播放器改为页面内独立安全区内容。首页组件、本地导入与播放业务保持原样。

0.1.6 将应用背景与卡片从绿色调整为深炭灰、暖白和铜色。首页、曲库、设置、导入、唱片架与播放器共用细横向织纹背景，启动底色同步调整；纹理由确定的原生 Canvas 路径绘制，保持静止，不跟随播放或滚动刷新随机图案。封面图像保留原色，系统原生 TabView 保留。

首页折页新增向下拖动展开、向上推回收起、松手吸附与点击切换。顶部四块统计面逐渐摊平，下面两段折面按同一进度绕水平折痕旋转，布局高度与投影同步改变；展开后提供导入、唱片架、喜欢、试听入口，使用现有数据与同一个 PlayerStore。页面只保存收起/展开的视觉落点，临时拖动由 GestureState 管理；取消拖动恢复落点。手势从折页内开始时操纵折页，其他位置继续滚动首页。减少动效时去掉三维翻转和回弹，点击与拖动仍能操作。参考用户提供的 QuickTime 录屏和深灰横纹截图，实际触感仍待用户真机体验确认。

0.1.7 将首页原指针仪表换成参考图中的机械数字转轮面板：矩形与斜口窗口后各有一个纸质数字轮，按实际已播放和剩余秒数转动；下方三个数字窗显示曲库序号、已播放与剩余时间。暂停后停止，切歌重置；播放、下一首和进入完整播放器仍使用同一个 PlayerStore。数字窗使用原生数字滚动过渡，减少动效时关闭转轮与数字过渡。装饰面板不参与触摸，避免裁切外的转轮挡住上方折页。

首页保留标题、收藏折页、机械播放卡与横向专辑架，移除重复的喜欢/随机卡、收藏预览、底部导入卡和装饰尾注；导入、喜欢和试听仍可从展开的折页进入，曲库与设置中的导入入口保留。没有虚构收听统计或历史数据。

0.1.8 只调整机械播放卡：参考原图收紧为低矮面板、小数字窗、金属铆钉与两个纸轮开口。纸轮以真实圆盘旋转，支持左右拨动、松手短距离惯性和按刻度停住；手动拨动只改变纸轮的视觉偏移，不跳转音频。下方仍显示真实曲序与播放时间。数字按位经过有透视的滚筒，分钟/秒进位、倒计时和切歌采用各自的转动方向；取消原来整卡按歌曲重建的处理。

播放时由当前音频快照校正视觉相位，最多补间 400 ms，不以视觉时钟生成媒体位置。暂停和曲尾停止推进，跳转或换歌选择最近的等价角度；减少动效关闭自动过渡与松手惯性，直接拨动仍可操作。纸轮触摸范围限定在上方开口，避免影响折页。数字窗通过独立的辅助功能表示读出一次数值，装饰字形不重复朗读。首页标题、折页、专辑架、背景、底栏和导入/播放业务源码保持原样。

本版 29 个单元测试、4 个相关界面流程验证通过；其中最终三项界面测试正常结束。覆盖了相位连续、进位、暂停、短弧重置、手拨不定位、减少动效、唯一辅助功能读数和折页手势。截图与手拨录屏位于 `Evidence/0.1.8`。Release 签名、覆盖安装和启动已确认；最终真机视觉与触感仍由用户体验确认。完整构建与分轮结果见 `BUILD_RECEIPT.json`，上版安装记录保存在 `Evidence/0.1.7-installed-receipt.json`。

0.1.9 将专辑与唱片拆为两个场景入口。封套通过同一 artwork namespace 展开到唱片廊，横向拖动调整封面的透视、位置与层次，松手吸附；点击封面将该专辑放回唱盘，保留原播放/暂停状态，点击聆听或歌曲则进入纯唱片播放。唱片廊由根布局编排，不使用系统 sheet 或 fullScreenCover。设计参考 [引力音乐的官方介绍](https://apps.apple.com/cn/app/id6804377291) 中以封面为中心的音乐墙、Cover Flow 与场景流转方向，未宣称逐帧复刻其动效。

点击黑胶会直接开始音频播放，同时封套退出、周围 UI 淡出、唱片移到中央，唱臂延迟落针。落针只是可取消的视觉反馈，不是播放完成条件。唱片轻点切换播放，水平轻扫切歌，向下拖动返回；唱臂保留独立的定位手势。滑动后的按钮释放不会再触发播放切换，切歌会取消旧唱臂手势。VoiceOver 提供返回、切歌与进度操作；减少动效保留交叉淡入淡出及全部功能。歌词仍不展示。

本轮保留首页标题、折页、机械转轮、卡片布局、横纹背景和原生底栏，只将首页专辑入口接到新的唱片廊；音频与本地导入服务源码保持原样。32 个单元测试与 19 个界面用例完整通过，随后对最终菜单、专辑与唱臂修改重跑 4 项针对性界面用例，均通过；两轮合计覆盖 20 个不同界面用例。菜单长按遇到 XCTest 在持续更新媒体快照时等待动画结束，最终菜单用例采用暂停状态，单独检查长按不切换播放状态、收藏恢复与后续首页入口。普通动效的进入、退出与切歌已由完整回归及录屏覆盖。没有把不同轮结果描述为最终源码再次跑过完整套件。

截图与两段正常动效录屏位于 `Evidence/0.1.9`；Release 签名、0.1.9 / build 10 覆盖安装及前台启动均确认，未卸载或清理数据。最终真机视觉、手势与音质仍由用户体验确认。前一版记录保存在 `Evidence/0.1.8-installed-receipt.json`，失败与中断轮次及其修复原因见 `BUILD_RECEIPT.json`。

0.1.10 修正上一版像直接切页的进入体验。点击时捕获封套所在视口的真实全局坐标；根场景接过同一份唱片几何，播放中的唱片组件在整段动画内保持挂载，不再依赖跨 TabView 宿主的黑胶匹配。2.25 秒的统一视觉进度依次控制封套略微后退、唱片完全滑出、移到唱盘位置、放稳、唱臂落针和小控制区出现。封面抽出后才退出；唱片放稳前唱臂保持抬起。其他页面进入时没有封套来源，使用较短的淡入与落针；减少动效只淡入，不沿轨迹搬运。媒体播放由原有 PlayerStore 立即启动，不等待视觉动画完成；离开页面会取消视觉完成任务。

播放构图参考用户提供的 [Rafikki Studio 图片左侧播放器](https://www.rafikkistudio.studio/Music-player/vinyl-music-player-balanced.webp)：大唱片占据上半部、右侧深色唱臂、随实际封面变化的暗色氛围、底部小字歌曲信息和三个轻量按钮。保留唱片轻点、左右切歌、下滑返回、唱臂定位与长按菜单。首页卡片、折页、机械纸轮、原生底栏、专辑廊和导入/音频服务未修改；封套原布局仅提取共享几何以保证转场起点一致。

源码行数检查通过，65 个维护代码文件最多 447 行。最终 35 个单元测试和 8 个针对性界面用例通过，覆盖抽出/落针时序、分段连续性、实际坐标、减少动效、播放与前后切歌、手势返回、唱臂定位、菜单收藏、大字体和迷你播放器。首轮发现浮点边界断言需容差，以及自动化在唱片放稳前取得按钮；最终让移动中的唱片与可操作按钮具备明确的辅助功能状态，再重跑上述检查。正常动效录屏和最终截图在 `Evidence/0.1.10`，完整结果见 `BUILD_RECEIPT.json`。Release 签名、0.1.10 / build 11 覆盖安装及启动已确认；未卸载或清理数据，真机视觉、触感和音质仍待用户体验确认。前版记录保存在 `Evidence/0.1.9-installed-receipt.json`。

0.1.11 为播放页切歌增加约 0.9 秒的抬针、旧唱片滑出、新唱片入位和落针动画，背景与歌曲信息同步淡变；上一首采用相反方向，暂停切歌保持暂停，减少动效只交叉淡入淡出。视觉层最多保留两张唱片。快速连续切歌会取消较早的完成任务，所有播放与切歌操作仍立即作用于 PlayerStore 当前歌曲；保留的旧封面和唱臂比例仅用于绘制，不生成或回写音频进度。

渲染优化包括：用原生 Core Animation 旋转缓存的 512 像素标签，移除固定 30 Hz 的 SwiftUI 标签时钟；将录音室唱片的 112 圈沟槽预绘为静态资源，阴影只附于静态表面；将全屏实时模糊改为按封面生成的 128 像素背景纹理，滤镜在后台计算，取消旧请求后不写回纹理；首页被盖住、切到其他标签或尚未滚入首页时，暂停机械纸轮与数字装饰动画。首页布局和视觉、手拨纸轮、专辑廊及音频/导入服务保持原样。首轮回归发现优化后的快速响应会使滑动后的新轻点落入旧的 250 ms 屏蔽窗口，已缩短为仅屏蔽释放事件的 80 ms，并重跑该流程。

性能采用相同 Release 模式、iPhone 16 Pro / iOS 27 模拟器、稳定播放场景，对比各 3 次 4 秒采样；采样期间不录屏。应用 CPU 时间平均从 0.956 秒降到 0.655 秒，约减少 31.5%。这是应用 CPU 对比，不是 iPhone 真机帧率、GPU 或耗电结论。明细在 `Build/track-change-performance-comparison.json`；模拟器没有输出可用的逐帧 Hitch 指标，不宣称已证明真机完全无卡顿。

源码检查通过，73 个维护代码文件最多 447 行。各轮共通过 38 个单元测试、12 个不同功能界面用例及一个性能用例；最终针对异步背景和切歌重跑性能与连续切歌，正常结束。覆盖普通/减少动效、暂停/播放切歌、快速双击选择、滑动后轻点、后台音频、大字体、唱臂定位、菜单收藏与原有机械组件。没有把分轮结果描述为最终源码重新跑过完整套件。最终截图与播放中切歌录屏在 `Evidence/0.1.11`，分轮记录和限制见 `BUILD_RECEIPT.json`。0.1.11 / build 12 的 Release 签名和覆盖安装已确认，未卸载或清理数据；用户解锁后已核对手机版本并成功前台启动，真机流畅度和触感仍待用户体验确认。前版记录保存在 `Evidence/0.1.10-installed-receipt.json`。

## 结构

```text
Stillroom/
  App/         入口、导航和导入选择器编排
  Domain/      歌曲、自制唱片版本、双面边界、歌曲记忆、歌词与导入规则
  Services/    安全暂存、曲库与唱片存档、手工覆盖、图片裁切、音频与系统会话
  State/       PlayerStore 唯一播放协调；导入与唱片存档分别协调
  Design/      色彩、封面、黑胶与独立视觉转动
  Features/    Crafted 制作／收藏／记忆；Orbit 首页、播放器、曲库与设置
  Resources/   三首原创试听、海边封面、字体及其许可
StillroomTests/      业务边界、实际 WAV 导入与音频引擎测试
StillroomUITests/    导航、播放、沉浸布局、进度定位、大字体、后台、选择器及偏好保存
Tools/              工程生成、原生矢量图标绘制、源码行数检查
```

展示组件接收数据与回调，不自行持有播放器或访问授权来源。当前 AVPlayer 由 AudioPlayback 唯一持有，统一播放本地文件和远程流，PlayerStore 消费真实快照；MusicImportCoordinator 通过固定目标回调提交资料，不另建播放状态。音频会话激活在独立 actor 中串行执行，并用请求代次防止延迟激活覆盖暂停／切歌。LibraryRepository、ImportStaging 和 MediaOverridesStore 分别负责曲库事务、文件暂存与持久手工覆盖；CraftedRecordsStore 协调 CraftedArchiveRepository 的本机唱片与记忆存档，CraftPhotoProcessor 处理授权照片与裁切。自制唱片会话只持有制作版与双面边界，媒体位置继续来自 AudioPlayback；轻量外观与续听偏好使用 UserDefaults。

## 构建

本次环境 Xcode 27.1 / Swift 6.4 工具链；源码使用 Swift 5 语言模式，最低 iOS 18，仅面向 iPhone。项目无第三方运行依赖。

本机签名团队只写入被忽略的 `Config/Signing.local.xcconfig`：

```xcconfig
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

```sh
node Tools/check-source.cjs
xcodebuild -project Stillroom.xcodeproj -scheme Stillroom \
  -destination 'generic/platform=iOS' -derivedDataPath Build/Device \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration build
```

测试新建独立 QA 模拟器，不使用用户正在预览的模拟器或其他窗口的 QA。下例只运行不依赖账户的针对性模型套件；原生文件／远端 UI 流程需要相应测试资料与前置顺序，见本轮凭据。

```sh
ONETAPE_QA_DEVICE=$(xcrun simctl create 'One Tape Function QA' \
  com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro \
  com.apple.CoreSimulator.SimRuntime.iOS-27-0)
xcrun simctl boot "$ONETAPE_QA_DEVICE"
xcodebuild -project Stillroom.xcodeproj -scheme Stillroom \
  -destination "platform=iOS Simulator,id=$ONETAPE_QA_DEVICE" \
  -derivedDataPath Build/Simulator-QA -parallel-testing-enabled NO \
  -only-testing:StillroomTests/OneTapeSourcesTests \
  -only-testing:StillroomTests/OneTapeFavoritesTests \
  -only-testing:StillroomTests/OneTapeLibraryHistoryTests \
  -only-testing:StillroomTests/OneTapeLibraryQueryTests \
  -only-testing:StillroomTests/OneTapeTransportTests \
  -collect-test-diagnostics never test
```

模拟器也保留 Xcode 正常签名流程，以嵌入 Keychain 所需的 simulated entitlements；不要给当前连接测试加 `CODE_SIGNING_ALLOWED=NO`。真实 Navidrome 测试通过仓库外的私有配置显式启用，没有配置时明确跳过，不把跳过算作连接验证。

照片界面用例需要在专用模拟器的照片库中准备项目自有 SeaCover 测试素材。0.1.x 的历史界面套件对应旧页面入口，不作为本轮当前流程回归命令的一部分。

工程已生成并可直接打开。以后增加源码文件，可使用本机已安装的 Ruby `xcodeproj` gem 执行 `ruby Tools/generate-project.rb` 重新生成；它不会复制签名材料。`Build/` 下包含编译日志与 xcresult，均不纳入版本管理。

## 证据与边界

当前艺术工作的证据由根 `BUILD_RECEIPT.json`、[古铜与字体凭据](Evidence/0.4.0/build42/BRONZE_BUILD_RECEIPT.json)及[印花重绘固定凭据](Evidence/0.4.0/print-redraw-v1/BUILD_RECEIPT.json)分别记录。下文均为旧版本历史：0.3.1的最终构建、签名、分轮测试与真机安装／启动由 [0.3.1固定凭据](Evidence/0.3.1/BUILD_RECEIPT.json)记录；[0.3.0固定凭据](Evidence/0.3.0/BUILD_RECEIPT.json)单独保留，不混用历史包证据。[0.2.0 固定凭据](Evidence/0.2.0/BUILD_RECEIPT.json)单独保留。[0.1.11 原构建记录](Evidence/0.2.0/previous-0.1.11-receipt.json)已保留，不能证明后续版本安装。截图位于 `Evidence/`，区分 simulator 与 iphone；build 13 的实机画面属于历史中间包，build 15 的最终唱臂画面来自模拟器。构建成功、自动化测试、设备安装／运行和用户视觉／手感认可分别记录。

0.1.7 首轮测试曾出现 3 个折页交互失败，随后按用户要求中断。源码检查发现装饰转轮的触摸范围会越过裁切边界，已关闭装饰层触摸，并增大轮盘以拉开数字间距。10 月 21 日重新验证中，22 个单元测试和 4 个针对性界面用例全部通过：折页拖动展开/收起、减少动效下的折页入口、精简首页后的喜欢与导入，以及机械卡播放/暂停/切歌。用例执行后，Xcode 测试进程在结果归档阶段停滞，已发送中断清理；用例通过依据日志记录，不表示整条测试命令正常结束。Release 构建和签名检查通过，0.1.7 / build 8 已覆盖安装并在用户的 iPhone 16 Pro 成功启动；未卸载或清理数据。最终真机视觉和触感仍由用户体验确认。上次安装证据保存在 `Evidence/0.1.6-receipt.json`，仅源码交接证据保存在 `Evidence/0.1.7-source-handoff-receipt.json`。

当前没有本产品账号、Apple Music 订阅曲库访问、远程音频离线缓存管理、曲库删除或跨编码歌曲合并；build39已接入独立 Navidrome 登录和流播放。音频候选的实际兼容以 iOS 解码结果为准，DRM 订阅下载不支持。0.2.0 已有独立歌词／封面覆盖和明确作用范围，旧版“没有封面编辑”“歌词仅运行期”的描述只属于上方历史版本；完整元数据编辑仍待实现。0.3.0 已为自制封套和歌曲记忆增加照片入口与交互裁切，未将它们描述为原歌曲／专辑封面编辑器的功能。

尚需覆盖的发行场景包括：大量音乐、超长歌词、所有大字体尺寸、蓝牙设备组合、来电和音频中断的完整设备矩阵、长时间耗电，以及最终视觉和触感验收。

本轮只修改 iOS 工程；鸿蒙工程与网页未修改。三首试听、海边封面和 Damion 字体从原生项目现有资源复制；窗边/月夜封面及图标由代码绘制。Damion 使用 SIL OFL 1.1，原许可保留在 `Stillroom/Resources/Damion-OFL.txt`。

