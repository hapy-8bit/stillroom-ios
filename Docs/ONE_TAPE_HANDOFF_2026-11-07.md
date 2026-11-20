# One Tape 接续交接 · 2026-11-07

> **build53 按机身三键材质与短按绕带**：左下三键保持58点，以原黑照片／协调浅色及彩色材质统一底面、灯面、方向与按压。播放短按先暂停同一引擎，±14×650ms快转→0×140ms停顿→ID/修订号确认后恢复；暂停态不创建自动播放。原模拟器已保留数据安装正常签名build53，54模型/集成/渲染+2UI共56项通过，6份原文件SHA及外观一致。来源拨杆/背面/B面未入App。

> 交付包为 `Build/TransportFinish53/.../Stillroom.app`，独立凭据 `Evidence/0.4.0/transport-material-windup-20261107/BUILD_RECEIPT.json`。并行屏幕源改动后的固定快照另有格式断言失败，未交付；不能拿后续快照覆盖通过包，也不把重复测试累计。原根BUILD_RECEIPT仍属于屏幕build52，保留其历史证据。

> **三键、切歌声与矩形黑框（0.4.0/build51）**：用户要求缩小三圆键、上一首／下一首加音效、修正切换机身后的黑框。显示直径改 58 点，源图尺寸仍 65.33，先清除完整旧圆区再重采样绘制，按压／亮面／旋转图标共用目标尺寸，中心不变、间隙 10 点，触摸至少 44 点。黑框源于 ClassicStill／CoverClassicStill 376.33×576 全不透明画布的矩形黑底；在 PlayerFace 固定磁带层按与玻璃一致的真实圆角槽口裁切，原 PNG 不改。八种黑／石墨／白／鸽灰 × 开／关盖完整渲染比较旧黑底位置与机身，并防止磁带缺层误通过。切歌声 `.trackStep` 是同一 CC0 录音首段约 0.158 秒的机械接触，资源及原始摘录／哈希／许可已登记；Store 仅对前台有效切歌或同曲重播响一次，空库、外部／自动、恢复和同步失败静音，绕带长按不重复敲击。原音乐引擎、媒体时钟、音效服务及 B 面未改。

> build51 源码检查与正常签名实际构建／核验通过，最终同轮 **41 项（39 模型／集成／渲染＋2 UI，0 失败／跳过、运行时警告为空）**通过。首轮因测试误写系统只读 Reduce Motion 环境键编译失败，修正测试注入后重跑，未降低断言，失败证据保留；不把两轮累计。独立 QA 仍为 `145AB0F0…`。原预览 `77CFAADC…` 已保留数据更新 build51，CUA 短按下一首再上一首回原曲、实际切换石墨／白色核对，并恢复原黑色／沙丘／城市／空白品牌／开盖外观和暂停主页；一次 HUD 超时后的点击曾切换屏幕，已通过面板恢复沙丘，最终持久化外观逐字段相同。六份原曲库／唱片文件哈希不变，五份安装产物匹配测试包。实体设备和完整路由／窗口／辅助功能矩阵未验收，没有卸载／清数据、手机安装、提交或发布；独立凭据见 [build51](../Evidence/0.4.0/transport-buttons-body-20261107/BUILD_RECEIPT.json)，根 BUILD_RECEIPT.json 不覆盖。

> **真实机械按键音色（0.4.0/build50）**：用户确认希望“更像真实磁带机的机械咔嗒”。两段音效改用 Joseph SARDIN / BigSoundBank 0570 的 CC0 磁带机实录摘录，播放约 0.343 秒、暂停约 0.365 秒，保留真实按键时序，处理底噪／频段并限制峰值；原版 Cassette 应用音频未使用。`Tools/AudioSources/Transport` 留下无损输入、帧区间、SHA 与许可，`Tools/generate-transport-sounds.py` 可离线确定性重建，包内 `PROVENANCE.json` 保留作者与来源；完整长录音只在忽略的 Build。没有改 Swift 服务、播放策略、0.65 增益、视觉、按键间距或 B 面。源码检查与正常签名构建／签名核验通过，独立 QA `145AB0F0…` 的 11 项（7 服务＋4 实际引擎集成）通过，0 失败／跳过、运行时警告为空；既有 UserDefaults Sendable 编译提示仍在。原预览 `77CFAADC…` 已保留数据更新至 build50，四份产物与测试包一致，六份曲库／唱片文件哈希不变；CUA 点按实播后再次暂停，保留原外观与曲目。主观听感及实体路由矩阵待验收，未安装产品手机、提交或发布。[独立凭据](../Evidence/0.4.0/transport-audio-refinement-20261107/BUILD_RECEIPT.json) · [试听：播放→暂停](../Evidence/0.4.0/transport-audio-refinement-20261107/play-then-pause-preview.wav)

> **原版 A/B 补充核实（研究，无产品改动）**：局部原生指令确认至少两首时 `trackIndex >= floor(trackCount / 2)` 为 B，前半 A、后半 B，奇数时 B 多一首；普通单曲加载默认 A，但恢复状态与手动路径并非强制 A。原版现有 iPhone 同一张五首专辑实测第 2 首 A、第 3 首 B，暂停切歌跨分界没有 3D 翻转；录像中关盖前 111 帧外壳 A 字区域位置均不变。分面区间也用于按真实时长计算磁带进度。手动翻面代码在 `PadPlayerView / DuoOpenPlayerView → PadTapeFlip → TapeTransport`，有“翻转磁带”命名操作、1.5 秒动画配置及切至另一面首曲逻辑；相关设备入口与动画未验收，当前 iPhone 开盖点按也未触发，不编造步骤。六次独立原版研究 XCTest 执行通过，没有替换原版、导入／清数据、购买或安装 One Tape 到手机；结束恢复同专辑第 3 首 B、暂停、玻璃关闭，媒体时间为 0，并未精确恢复原 0:03。One Tape 仍 build49、固定 A，按用户要求不实施 B，不重建／重装产品。[独立研究凭据](../Evidence/0.4.0/cassette-side-audit-20261107/BUILD_RECEIPT.json)

> **音效与三个按键间距（0.4.0/build49）**：按用户要求新增原创播放锁扣／暂停释放短音效，OneTapeMusicStore 仅对前台明确操作建立意图，再由真实引擎 snapshot 确认；不新增音乐时钟／队列。音效原生预加载移出 UI actor，快速替换、失活、失败及外部暂停均有取消／释放路径。按键中心改 `666／734／802`、直径保留，绘制／点击／颜色排除区共用布局；机身原 PNG 未改，黑／白原始像素核验无旧圈残留、脸部或 LCD 染色。首轮 33 项通过但发现音效准备主线程警告；最终同轮 35 项（33 模型／集成＋2 UI）全过且运行时警告为空，不累计。已保留数据覆盖更新原预览至 build49，六份原数据哈希不变，实播后停在原有曲目暂停主页；完整证据见 [build49 凭据](../Evidence/0.4.0/transport-details-20261107/BUILD_RECEIPT.json)。用户明确 B 面先不做；原版具体翻面入口仍未核实，不编造双击／长按／滑动步骤。未安装产品到实体手机、提交或发布。

> **顶部淡入淡出与模拟器更新（0.4.0/build48）**：按用户新要求，仅将 Root 顶部设置控件 transition 从 opacity＋move(top) 改为 opacity，保留 0.4 秒／减少动效分支和底栏过渡。正常签名构建及源码检查通过；主轮 4 项、补充设置／选择器取消隔离复跑 1 项通过，共 5 项不同检查分阶段通过，补充首轮失败与边界保留在 [build48 凭据](../Evidence/0.4.0/hud-fade-20261107/BUILD_RECEIPT.json)。原始视频模板匹配支持顶部位置固定、透明度变化。用户本轮明确要求构建到模拟器，因此已保留数据更新原预览 `77CFAADC-0D5D-4E5B-864A-B5019465A476` 至 build48，六份原数据文件哈希一致；CUA 已检查唤出 UI、打开设置并返回暂停主页。此前不操作原预览的自动化约束不应用来阻止这次明确授权的覆盖更新；测试仍只在独立 QA。未卸载／清数据／操作实体手机。A／B 面已向用户说明：当前 One Tape 只有固定 A 标记，未接分面／翻面队列；不混用 legacy Crafted 双面功能。没有新增该功能或改动并行美术实现。

> **最新字号与图标修正（0.4.0/build46）**：按用户截图反馈，对照已有原版记录缩小详情播放按钮、当前歌曲与底栏字号；修正磁带小图标纵横比／描边、书本第四斜脊的四边闭合与重叠，去掉额外选中圆底。没有改物理磁带美术、印花、动态屏幕或媒体时间。源码检查、正常签名实际构建及最终同轮 4 项针对性检查（3 模型＋1 UI）通过，见 [build46 独立凭据](../Evidence/0.4.0/detail-refinement-20261107/BUILD_RECEIPT.json)。**此前“暂停后缺层”的工具图像判断已撤回**：用户解锁后以 CUA 在 DeviceHub 常规图标启动同一 build46，手动播放、暂停、返回并静置；直接核验原始 PNG 后，最终初始／返回／静置四图同 SHA，手动两次静置采样亦同 SHA，关键文字与图标像素保留且不透明。不要再依据工具内不完整呈现修改正常的生产渲染；图像展示差异原因未确认。Root compositingGroup 实验已完整回退。手动像素证据不增加 XCTest 数量，完整辅助功能／实体设备矩阵仍未验收。自己的 QA 仍为 `145AB0F0-7904-472C-9A3E-D78A78D5440B`，现名 One Tape Detail QA46，停在本地测试专辑暂停详情；没有操作原预览、其他 QA 或实体手机的安装／进程。下方历史测试数量不并入本轮。

> **最新确认与验证（0.4.0/build45）**：用户明确 ¥9.90 为一次性买断。Studio 和设置说明已同步“不自动续费”，当前未开放购买，不发起收费或恢复权益。源码检查、实际 Xcode Simulator 构建、签名与 5 项针对性检查（3 模型＋2 UI，0 失败／跳过）通过，见 [build45 凭据](../Evidence/0.4.0/buyout-20261107/BUILD_RECEIPT.json)。下方 build44 的 70 项为历史阶段结果，不并入本次数量。独立 QA `145AB0F0-7904-472C-9A3E-D78A78D5440B` 已更名 One Tape Payment QA45；原预览、其他窗口 QA 与实体手机未操作，未提交／发布。

> **后续用户要求已落地（0.4.0/build44）**：本地封面补齐内嵌图片、同目录 cover/folder 整专辑建议、后续曲目图片回退及缓存刷新；本地专辑封套长按可选择图片，走固定整专辑预览确认，保留单曲例外。设置新增离线隐私／用户服务／付费说明与联系／反馈，邮箱为用户明确提供的 `hapy8bit@163.com`，build44 显示计划价人民币 9.90 元，当时购买类型仍待确认；用户后续已确认一次性买断、不自动续费，说明文案已在后续 build45 更新。当前尚未开放购买，不发起真实付款或发送测试邮件，也不承诺所有未来功能。以下 build44 的 70 项不同检查同轮通过，最终文字对比调整后重复通过 2 条支持 UI；build45 买断文案的新整合验证另行记录，不沿用该检查数量。原音乐字节校验与模拟器页面见 [build44 独立凭据](../Evidence/0.4.0/covers-support-20261107/BUILD_RECEIPT.json)。只使用本窗口自己的 QA UUID `145AB0F0-7904-472C-9A3E-D78A78D5440B`，没有操作原预览／其他 QA／实体手机，未提交或发布。印花、磁带、屏幕与定制渲染／图片资源未改动；Studio 仅修改功能说明文字与付费说明事件。

> **接续执行结果（0.4.0/build43，2026-11-07）**：下面 P1 缺口清单是交接前的历史状态。来源断开／远端统计／文案、设备收藏与远端冷恢复、真实最近添加／持久化最近播放已完成；另修快速切歌准备期意图、首次导入协调器发布时机，补常亮持久化及旧凭据清理重试。独立 QA 分阶段通过 73 项模型／集成与 7 项 UI，不将重复执行相加。原生导入、混合库刷新／断开和冷恢复已有本轮证据；独立 QA 的 12 个本地文件断开前后哈希一致。详见 [独立构建凭据](../Evidence/0.4.0/sources-library-20261107/BUILD_RECEIPT.json) 与 [README](../README.md)。未操作原预览 UUID、其他窗口 QA 或实体手机，未提交／发布。保留并行美术／屏幕改动，未接手其实现；P2 的真机系统路由、完整格式／网络中断矩阵、历史偶发退出归因及本文延后范围仍不能视为已验收。

## 接手范围和第一件事

用户要求：完成本轮交互和稳定性处理后，把相对原版尚未完成的内容交给本项目的新窗口，继续执行。产品方向是**本地音乐导入 + Navidrome**，不是继续开发旧 Stillroom 唱片界面。

**印花、磁带、屏幕的美术与动画已交给其他窗口，本接续窗口全部排除。** 不重绘资源、不改材质/着色器、不调整磁带展开、卷轴、动态屏幕等动效。搜索交换和播放灯已完成，保留现状；只有功能回归才修复相关触摸或状态问题。共享页面必须小范围修改，保留其他窗口的未提交工作。

接手后直接开始：核对本文件与当前源码 → 补齐音乐来源页的断开账户入口、准确统计及设置文案 → 修正曲库收藏/排序的功能闭环 → 验证本地导入与播放异常路径。不要再停在一份新规划或等待用户重复授权。本文后面的“小组件等延后范围”不属于本次自动实施清单。

工作目录：`/Users/liuhang/Documents/Google_Project/stillroom-ios`。沿用这个本地 checkout；用户没有要求新建 worktree。当前整个工程主要是 Git 未跟踪文件，不能根据 `git diff` 为空判断没有其他窗口的工作，更不能 reset/clean。

## 当前基线：已实现，接续时不要重做

本交接核对时 `Config/App.xcconfig` 为 **0.4.0 / build42**，显示名 One Tape，target/scheme/module 仍为 Stillroom，Bundle ID 仍为 `com.liuhang.stillroom`。后续窗口可能继续更新版本，先读当前配置，不覆盖回42。

| 范围 | 当前行为与证据 |
| --- | --- |
| 空库主页 | 默认空音乐库，不创建旧示例歌曲/音频。播放、切歌不制造媒体时间。浮动导航、来源、设置、资料库均有入口。见 build36 原版观察与后续实现。 |
| 有音乐资料库 | 专辑/播放列表、封套目录、专辑/歌单曲目、播放/随机播放、当前曲目标记、曲目时长已接真实数据。原版研究时使用 Apple Music；One Tape 用本地与 Navidrome 模拟相同有音乐场景。 |
| 搜索 | 搜索从右侧展开、原工具左退，关闭清空查询/收起键盘、工具从左侧恢复。按专辑/艺人/歌曲元数据过滤集合，不是独立全局歌曲结果页。已有针对性 UI 流程通过。 |
| 专辑选择 | 已完成先立起、上移、停稳后显示列表。淡入完成后才启用点击；任务在离页/数据失效/减少动效时取消或收束。后续美术与动画调优不归接续窗口。 |
| 播放键 | 由唯一引擎的 playing/preparing 状态驱动暖银色持续亮起，按住变暗，暂停熄灭。不是按下就假亮。 |
| 本地导入 | 已接原有 `MusicImportCoordinator` 与系统文件选择、预览、确认、逐项结果、重复复用及事务服务。不能写成“尚未接入”；One Tape 新入口的完整文件选择闭环仍需复核。 |
| Navidrome | 已有连接、分页专辑、歌单、封面、刷新、HTTP 原流播放、缓存目录/凭证恢复。token+salt 请求；密码 Keychain，远端 JSON 与本地索引分离。断开有 Store 方法，当前没有 UI 入口。 |
| 统一媒体状态 | `OneTapeRoot → OneTapeMusicStore → PlayerStore → AudioPlayback`，同一个 AVPlayer 处理本地与远端。不要增加另一套播放器/播放时钟。 |
| 播放队列与恢复 | 点曲替换真实队列；随机播放复用同一队列。长按两端键以真实 seek 约±6倍卷带；松开保留此前播放意图。冷启动恢复可用歌曲/队列/位置且不自动播放。 |
| 方向变化 | 原版在关闭方向锁定后仍保持整机竖向，只旋转内部显示和按键，右向时两端前后曲角色互换；One Tape 已按此处理。不能把“整页横屏缺失”列为已证实差距。 |
| 分析信号 | 同一个 AVPlayerItem 的 PCM tap 供现有屏幕消费，不再下载整曲分析、不请求麦克风、不伪造幅度。保留信号接口，屏幕设计由其他窗口处理。 |

## 确定存在的非美术缺口：按顺序执行

### P1 · 音乐来源、账户和产品文案

1. **断开 Navidrome 没有界面入口。** `OneTapeMusicStore.disconnect()` 已有取消、持久化、移除远端并保留本地的实现；`OneTapeSourcesView` 和 `OneTapeRoot.panelContent` 没有对应事件。补上当前账户的明确断开操作和忙碌/失败处理，清楚说明只移除此设备的连接，不删除服务器音乐。避免新建第二套清理逻辑。
2. **已连接统计混入本地。** Root 把 `music.albums.count` 和 `player.libraryTracks.count` 传给 Navidrome 连接摘要；`rebuildCollections` 会合并本地与服务器。提供连接范围内的专辑/歌曲统计；用混合本地+远端回归证明断开和刷新时不误算。
3. **设置页仍沿用空库首版占位文案。** `OneTapeSettingsView.musicSource/about` 仍显示 APPLE MUSIC、“将在后续版本接入本地与 Navidrome”。应改为实际已支持的音乐来源、当前连接与添加音乐入口。保留合理的现有布局，不新增 Apple Music SDK。
4. **本地导入页仍有旧 Stillroom/唱片文案。** `Features/Library/MusicImportScreen.swift` 使用 `RoomBackground/RoomStyle`、文案“自己的唱片”“复制到 Stillroom”。在复用同一导入协调器和事务的前提下，让 One Tape 的入口、产品称谓和说明一致；旧 `--legacy-stillroom` 流程若仍保留，避免无条件影响它。不要借此重写磁带/屏幕美术。

建议触及：`OneTapeSourcesView.swift`、`OneTapeSettingsView.swift`、`OneTapeRoot.swift`、`OneTapeMusicStore.swift`，必要时为导入页增加由上层提供的产品展示配置。页面只发事件；账户、统计和持久化由 State/Domain/Services 承担。

### P1 · 曲库收藏与排序闭环

原版的 Favourites 与六种排序**菜单已实际观察**，但逐项筛选结果、收藏入口和完整随机队列规则尚未验证。下面是 One Tape 当前已暴露选项的自身功能缺口，不冒称已精确证明原版的内部实现。

1. **有 Favourites 筛选，无 One Tape 收藏操作。** `PlayerStore.toggleFavorite(_:)` 和持久化已存在，当前 One Tape 页面只读取 favorites，没有发出收藏事件。先核对原版已有菜单/曲目资料，选择不挤占原布局的曲目操作入口；收藏与取消应立即影响筛选并在重启后保持。不把它擅自实现成服务器 star/unstar；当前是本地偏好。**同时修复远端收藏恢复顺序：** `PlayerStore.restore` 当前先按已载入的本地 ID 对 favorites 做交集，`OneTapeMusicStore.restore` 后面才加载远端 catalog；远端收藏会提前从内存滤掉且不补回。必须用本地+远端收藏冷启动回归验证，不能只加按钮。
2. **Recently added 并非真正最近添加。** `OneTapeLibraryQuery` 的该分支不排序，注释称使用服务器顺序，但 `NavidromeClient.fetchCatalog` 请求的是 `alphabeticalByName`。依据服务端可用元数据/排序接口实现真实语义，本地也明确使用真实导入信息；没有日期不能伪造。先确认响应模型可用字段，必要时查官方协议文档。
3. **Recently played 只是页面临时记录。** `OneTapeLibraryView.recentCollectionIDs` 是 `@State`，仅该页 `play` 回调更新，冷启动丢失，也不能覆盖所有真实播放入口。将真实播放历史归入正确状态/持久化层，保证排序名实相符；不要通过动画帧或假媒体时间更新。

其他集合行为已有实现，先按实际故障调整：搜索关闭恢复查询/工具，专辑与歌单切换，当前曲目标记，顺序/随机点曲，返回后目录位置，刷新后失效选择收束。不要把现有全部功能又列为“未实现”。

### P2 · 本地导入、网络与播放的验收补齐

这些主要属于**已实现但未完成当前产品端到端验收**，先复现/验证，有真实缺陷再改代码。

| 路径 | 本轮应获得的证据 |
| --- | --- |
| 本地导入 | 从 One Tape 入口选择自有/可授权测试音频 → 预览 → 确认 → 专辑列表可见 → 点曲播放 → 冷启动保持。补取消、重复、损坏文件和伴随封面；失败仅清理本次暂存。不要导入用户私人音乐作测试素材。 |
| 混合音乐库 | 本地导入期间播放远端不被抢走；服务器刷新/断开只影响所属远端项；本地索引不混存远端 Track。现有 restore race 测试已覆盖部分，不等于新 UI 全验收。 |
| 服务器失败 | 错地址/拒绝访问/超时/取消/换账户/刷新失败仍保留原可用目录；失败提示不含签名 URL 或密码。已有模型测试，需补最相关 UI 闭环，不必重复无关全量测试。 |
| 音频失败与边界 | 网络中断、不可播放格式、拖动/长按到首尾、播完最后一首、连续切歌及后台恢复；验证唯一状态、无假进度、明确失败及取消。当前 `format=raw`；不可假定所有 FLAC/服务端格式都已实机接受。 |
| 系统媒体控制 | 已有音频会话/系统控制代码；锁屏、控制中心、耳机拔插、蓝牙路由、系统中断的完整真实设备矩阵尚未验收，不能直接写成“未实现”。产品实体手机安装/测试按用户当前授权范围处理，不能把研究原版的授权当作任意安装授权。 |
| 账户提交异常 | Keychain/目录提交已有顺序和失败保留逻辑；旧 Keychain 项删除失败当前被忽略，可能残留无引用旧凭证。先评估必要的可重试清理/注入失败检查，不得打印凭证。 |
| 常亮偏好 | `OneTapeStore.keepAwake` 当前默认 true、仅会话内生效，没有持久化；实际系统开关已接入。与其他设置持久化一起核对，不得误称系统功能完全未实现。 |

资料库字号、VoiceOver、安全区与不同窗口宽度也未完成全矩阵；只核对受影响功能，保留减少动效和系统返回。不要为“横屏”额外发明未观察的整页布局。

## 相对原版仍未完成，但本次不自动扩展

原版设置入口已观察到小组件、iPad 遥控器、聆听环境、Studio。当前对应情况：

| 原版范围 | One Tape 当前状态 | 接续处理 |
| --- | --- | --- |
| 主屏小组件 | 设置里只有三种尺寸预览，无实际 WidgetKit 扩展 | 列为后续产品范围，不在本次新增系统 target。 |
| iPad 遥控器 | 点击明确提示尚未接入，无配对/控制功能 | 延后；不能用假配对状态充数。 |
| Apple Music | 只有参考式入口，无 MusicKit 接入 | 用户产品方向是本地/Navidrome，本次改正设置表达，不新增 MusicKit。 |
| 聆听环境 | 占位开关，未接麦克风 | 不是当前本地/服务器音频分析的必要条件；不新增录音权限，不接手屏幕艺术。 |
| Studio 真正购买/恢复 | 外观展示/预览，未接真实商品与 StoreKit 交易 | 用户未要求商业化接入；不可伪造购买成功，不购买原版付费内容。 |
| 开屏引导 | 按用户要求跳过 | 不补做。 |

未研究到的原版操作，标记“尚未观察”，不能凭常见音乐播放器的功能清单推断它必然存在。不要自发增加离线下载、服务器写操作、歌单编辑、scrobble、独立队列页或后台同步等范围。

## 闪退调查：事实、修复与未解决边界

用户报告的是 **One Tape 模拟器** 偶发退出，不是 Cassette 原版。

- 已修复三处风险：封面取色 `CGContext` 外借指针生命周期；极小/不支持采样率导致非有限值转 Int；旧歌词导入在 await 后沿用数组下标。对应代码和回归在 build41/42 范围。**没有证据证明这三处解释全部历史报告。**
- 2026-11-07 09:14:16：HomeScreen 启动与调试启动交错，debugger 请求 force-quit `0xfbfbfbfb`。不是已确证的业务 SIGABRT。
- 09:40:15：更新后 PID14516 被 `testmanagerd` 明确请求 “Terminating for automation testing”，RunningBoard 为 SIGTERM/code0。**发起测试的具体客户端/窗口未建立归因。** 随后正常桌面图标打开，最后记录 PID16043；该 PID 只是当时快照，接手时不能假定仍存活。
- 专用 QA 做了10轮连续资料库/搜索/选曲导航，121.11秒同一 PID；原预览进程另外观察544.78秒未换 PID。样本有限，不能写成“所有闪退已根治”。
- 早期 `StillroomUITests-Runner` 缺 XCTest.framework 的 DYLD 崩溃属于测试宿主，不是产品进程。

**不得在用户正在看的原模拟器跑自动安装/重启 XCTest。** 自动化放在自己新建的独立 QA 模拟器，不克隆用户音乐数据，不碰其他窗口的 QA。排查真实偶发退出应记录时间、PID、termination reason、崩溃栈/诊断文件，区分测试主动终止、覆盖安装重启和产品异常。

调查原件：`Evidence/0.4.0/build41/crash-investigation-notes.json`、`Evidence/0.4.0/build41/stability-run.json`、`Evidence/0.4.0/build42/original-user-session.json`。没有新的 fatal 证据时，不在媒体引擎中堆猜测性重试。

## 设备与构建交接

| 设备/产物 | 边界 |
| --- | --- |
| 原预览：Stillroom iPhone16Pro / iOS27.0 | UUID `77CFAADC-0D5D-4E5B-864A-B5019465A476`。本轮一次覆盖更新 build42，最终普通图标启动，保留正常外观和目录。不要向它发自动化 terminate/reinstall；交付时一次正常覆盖更新并说明。 |
| 本窗口一次性 One Tape QA41 | UUID `7B7A3767-B096-47FA-8B20-3A635E25C494` 已关闭并删除；不能继续拿它当可用 destination。新窗口自己建 QA。 |
| One Tape Print Redraw QA | 属于艺术窗口，不得清理、重置或删除。 |
| iPhone15 上 Cassette | 参考 App：`com.jerrynkongolo.Cassette-player`，1.0.3/build9。USB 研究使用独立已签名助手，不重签原版。One Tape 本轮没有安装到实体手机。 |
| 构建基线 | scheme Stillroom，模拟器产品位于 `Build/OneTapeInteractions40/Build/Products/Debug-iphonesimulator/Stillroom.app`。目录40不等于当前版本40，应读 Info 和哈希。 |

保留数据的边界：当前已读取服务器目录 **50专辑/501歌曲/142歌单**；这是该次 demo 快照，不应硬编码。更新前后字节比较曾错误使用旧容器路径，**未建立全量文件哈希相等的证据**，不能宣称已验证音乐字节完整性；也没有证据表明发生数据丢失。本轮没有卸载、erase、清库或删除用户音乐。

## 代码地图与规范

先读根目录 `AGENTS.md`，以下为便于接续的定位：

| 职责 | 文件 |
| --- | --- |
| 页面编排/来源入口 | `Stillroom/Features/OneTape/OneTapeRoot.swift`、`OneTapeSourcesView.swift`、`Panels/OneTapeSettingsView.swift` |
| 曲库/详情事件 | `Stillroom/Features/OneTape/Library/OneTapeLibraryView.swift`、`OneTapeAlbumDetail.swift` |
| 音乐/账号协调 | `Stillroom/State/OneTapeMusicStore.swift` |
| 唯一播放状态 | `Stillroom/State/PlayerStore.swift`、`PlayerStore+OneTapeTransport.swift`、`OneTapeWindingController.swift` |
| 规则与模型 | `Stillroom/Domain/OneTapeLibraryQuery.swift`、`MusicCollection.swift`、`PlaybackQueue.swift` |
| 系统/网络/凭证 | `Stillroom/Services/AudioPlayback.swift`、`NavidromeClient.swift`、`NavidromeResponse.swift`、`NavidromeCatalogRepository.swift`、`NavidromeCredentials.swift` |
| 本地导入 | `Stillroom/Features/Library/MusicImportScreen.swift` 与现有导入协调器/暂存/提升日志服务 |
| 针对性检查 | `StillroomTests/NavidromeTests.swift`、`PlayerRestoreRaceTests.swift`、`MusicImportTests.swift`、`ImportPreviewTests.swift`；`StillroomUITests/OneTapeNavidromeUITests.swift`、`OneTapeInteractionUITests.swift` |

单文件最多800物理行，超过600评估拆分，不能挤代码绕过。页面只布局与事件编排；Store 协调、Domain 规则、Services 负责网络/系统/文件。媒体秒、逻辑点和资源像素分开。注释解释竞态、取消、生命周期和兼容。监听/任务有释放路径，异步失败可见，损坏索引不能覆盖。

新增源码后运行 `ruby Tools/generate-project.rb` 使生成工程包含新文件，注意并行窗口可能正添加源码。不要为了生成/构建错误删除艺术窗口的引用或文件。

修改源码须执行：`node Tools/check-source.cjs`、实际 Xcode Simulator 构建、与修改有关的 XCTest，并查看受影响功能页面。文案/文档不需要无意义的镜像实现测试。不要每次重复无关的全量套件。

使用正常 Xcode 模拟器签名。**不要设 `CODE_SIGNING_ALLOWED=NO`**：之前无模拟器应用 entitlement 的包曾令真实 Keychain 流程失败，不能用换 Bundle ID/卸载来“修复”。签名团队仅在被忽略的 `Config/Signing.local.xcconfig`，不复制授权/证书材料。

## 已完成检查与证据，不扩大结论

- build41 交互阶段：**106项不同的针对性检查通过，97模型+9 UI，0失败/跳过**。含真实 demo 连接/播放/卷带/恢复、PCM、导入/媒体模型、搜索、空态、玻璃及10轮连续路径。
- build42 最终整合：包含艺术窗口并行更新后重新编译，**搜索与真实播放/灯效2条重复 UI 流程通过**；不是106项全量都在最终42包重跑。
- build42 当时 source check：258个维护代码文件，最大598行，0超800；构建、签名和原模拟器安装代码哈希核对通过。后续艺术窗口可能已改动，接手时重新检查实际源码。
- 本轮没有产品实体手机视觉/音质/能耗验收，没有 commit、合并、发布、上传或购买。

优先阅读：

1. `Evidence/0.4.0/build42/BUILD_RECEIPT.json`：本窗口最终基线、检查与限制。根 `BUILD_RECEIPT.json` 可能被其他窗口更新，不要覆盖其凭据；用分目录保存自己的新证据。
2. `Evidence/0.4.0/build41/reference-observations.json`：最新原版搜索、选曲开合、播放灯 USB 实录；视频在同目录 `reference/`。
3. `Evidence/0.4.0/build41/interaction-preview.mp4`：11秒静音实际模拟器交互录像，属于独立 QA 的 build41 交互阶段，不是最终42原窗口录屏。
4. `Evidence/0.4.0/build41/{navidrome-test-summary,interaction-test-summary,regression-test-summary}.json`；`build42/integration-test-summary.json`：分阶段检查结果。
5. `Evidence/0.4.0/build39/music-integration-notes.json`、`orientation-runtime-observations.json`：媒体/服务设计与原版内部旋转。旧记录的 pending 状态须结合后来的41/42结果，不能当作仍待运行。
6. `Evidence/0.4.0/build36/reference-observations.json`：空库/设置初始观察；其中“有音乐未验证”等早期限制已经后续研究推进，不能照搬。

原版资料库选项和完整设置的原始 AX 分别在私有研究目录 `private/runtime-library-options/7E53B79E-8CDE-4C42-A3D6-968E4BC286C7.txt`、`private/runtime-settings-expanded/5435454A-F349-44DC-B4AD-CE6B675EE491.txt`；已选曲目详情在 `private/runtime-music-detail39/73F7FAC9-EEE4-43EC-8565-845AF7DAFD8A.txt`。仅作本机研究，不复制包含用户资料的完整层级到公共文档。

原版公开标识：Cassette Player，Jerry Munyoka Nkongolo，<https://apps.apple.com/ca/app/cassette-player/id6819145485>。此链接用于识别本次研究版本，不能据此声称最新商店状态。

## 私有研究访问：只引用路径，不搬运内容

研究根目录在工程外：`/Users/liuhang/Documents/Codex/2026-11-06/one-tape-cassette-research/`。

- 真实 demo 私有配置：`private/navidrome-probe/connection.private.json`，字段 `address/username/password`。仅测试运行时读取，不能输出、复制进源码/交接/日志，不能把带认证 query 的 stream URL 写入证据。
- UI 测试 opt-in：`ONETAPE_NAVIDROME_TEST_CONFIG`；实时 PCM 测试 opt-in：`ONETAPE_LIVE_CONNECTION_FILE`。均指向上述外部文件。生产代码不得自动连接 demo。
- USB 助手在 `usb-probe`，`run_scenario.py` 支持已授权原版的有限步骤研究。需要补观察时先读助手说明和已有场景，优先复用已有录像；不做新签名、不把用户账号/设备授权复制进工程。
- 用户允许原版出现 bug 时杀后台重进，但不允许清数据/改签名。产品实体手机安装不包含在此前原版观察授权里。

## 下一窗口交付要求

本次先完成上述 P1 来源和曲库功能闭环，再按 P2 有针对性验证。每个改动记录“实际行为、修改文件、检查结果、尚未验证项”，展示真实音乐与导入/来源受影响页面。发现稳定性新证据再继续修复；不要把测试器 SIGTERM 作为业务崩溃反复重构。

保留并行美术与动画工作，独立 QA 验证后只做必要的正常覆盖交付，保留用户数据和当前外观。更新 README 与自己的版本证据，避免覆盖其他窗口的结果。不要提交或发布。需要新产品范围（购买/遥控器/小组件/服务器写入）时另行说明，不把它们混入这轮基础功能补齐。
