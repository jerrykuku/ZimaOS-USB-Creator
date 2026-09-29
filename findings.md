# Findings & Decisions

## Requirements
- Synchronize the ZimaOS fork with `raspberrypi/rpi-imager` while retaining current work.

## Research Findings
- `upstream` is configured as `https://github.com/raspberrypi/rpi-imager.git`.
- `main` is 11 commits ahead of, and 321 commits behind, `upstream/main`.
- The current workspace contains uncommitted UI, telemetry-removal, and development-script changes.
- The workspace changes are preserved in commit `0d827864` and backup branch `backup/pre-upstream-sync-20260902`.
- A standard merge conflicts across branding, packaging, QML, and every translation file. Clean upstream changes can still be merged safely by using `-X ours` for conflicting hunks.
- The upstream merge completed as `43149125`. The only remaining worktree files are untracked planning records.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Commit workspace changes before the merge | Prevents the upstream merge from overwriting or entangling uncommitted work. |
| Create a backup branch before merging | Provides a local recovery point for the pre-sync fork state. |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| None | N/A |

## macOS launch compatibility diagnosis
- The current `build/zimaos-usb-creator.app` is arm64-only (`lipo -archs`) and all bundled Qt binaries are arm64-only. A release made on Apple Silicon without `--arch=universal` therefore cannot launch on Intel Macs.
- The app and bundled Qt libraries advertise `LC_BUILD_VERSION minos 13.0`. Qt 6.11 in this repository requires macOS 13, so macOS 12 or earlier is unsupported by the current toolchain.
- The inspected local app has an ad-hoc signature and `spctl` rejects it. This is acceptable for a local/dev bundle, but not for a distributed DMG; release output must be Developer ID signed and notarized.
- The requested distribution target is Apple Silicon only. Distribution commands now default to arm64, and the packaging script validates that every Mach-O payload contains the requested arm64 slice.

## Screenshot Review: Eight UI Issues
- Sidebar heading is oversized relative to the page title.
- Inactive sidebar labels have insufficient contrast.
- The right content frame leaves excessive empty space for a single device.
- Device cards do not expose a clear selected state.
- The disabled Next button is too faint and does not explain why it is disabled.
- The page title is too close to the content frame.
- The settings button still reads as a large gray tile despite having no border.
- The macOS native title bar is still visible and has not been replaced by a custom one.

## Additional Layout Requirements
- Keep an 8px gap between the right edge of the sidebar items and the sidebar panel.
- Use the same border color for sidebar navigation and the right content frame.
- Align the bottom action button baseline with the bottom edge of the sidebar.
- Reduce the settings button size while keeping it bottom-left aligned.

## Second Screenshot Review
- The outer application window is still rectangular while inner panels are rounded.
- The outer border is too prominent and reads like a browser frame.
- The custom title bar is too tall and has loose spacing around the title and traffic-light controls.
- The title bar lacks a clear visual separator from the main content.
- Sidebar vertical distribution leaves excessive empty space near the bottom.
- Inactive navigation labels remain too low-contrast.
- A single device leaves excessive unused height in the right content panel.
- The selected device border is visually too saturated blue.
- The vertical gap between the content frame and Next button is too large.
- Device icon and text block need stronger vertical centering.
- Sidebar and content panel corner radii/border colors are inconsistent.
- Fixed sizing causes excessive whitespace when the window is enlarged.

## Second Screenshot Priorities
1. Rounded transparent outer window and restrained border/shadow.
2. Title bar height and separator hierarchy.
3. Right content sizing and single-item vertical layout.
4. Sidebar text contrast and bottom-space distribution.
5. Device card selection treatment and vertical centering.

## 内容存储库恢复
- 提交 `0d827864` 删除了 AppOptionsDialog 的入口及整个 RepositoryDialog.qml。当前 C++ 仍保留自定义/默认存储库刷新接口。
- 保留用户已有 zimaos-manifest.json 修改。现有 build 已配置 Ninja 和 Qt 6.11.1。
- 实测发现旧版 openFileDialog 共用镜像选择信号，会被 OSSelectionStep 消费。已改为独立原生文件选择返回值，使用 QUrl::fromLocalFile 正确处理路径。
- 最终改动包含 AppOptionsDialog 入口、RepositoryDialog 恢复、CMake 注册、中文翻译及 UrlFmt 的本地文件 URL 转换；不改动 manifest。

## 仓库样式调整
- 开关 implicitWidth 等于 indicator 宽度，但默认 leftPadding 使图形伸出右侧；清零 padding 使其与编辑/保存按钮右侧对齐。
- 仓库对话框使用局部 radio 和输入框样式，保留其他页面控件样式。文件输入框和按钮共享一条圆角外框及中间分隔线。

## 2026-09-28 写入进度和按钮状态
- 当前工作区已有 .gitignore 修改和 zimaos-manifest.json 删除，保持不动。
- 写入条自定义 Rectangle 的宽度直接等于进度比例；非常小的正进度时宽度小于高度。
- ImButton 的 activeFocus 明确使用浅蓝填充；复选框和单选框仍继承 Material 背景。
- 当前 Qt 6.11.1 本地工具链和 Ninja 构建目录可用于验证。
- main.cpp 全平台设置 Basic；但 ImRadioButton 直接导入 Material，默认 indicator 带 Ripple。复选框和开关已经自定义 indicator，无需扩大修改。
- 新 ImProgressBar 固定轨道/填充几何、显式抗锯齿，正进度至少显示一个条高大小的圆点。未知总量用圆角滑动段，减少动态效果时保留静态段。
- 普通按钮、未激活切换按钮和设置按钮取消焦点蓝色填充，以 visualFocus 边框保留键盘反馈。
- Qt 官方 Rectangle 文档确认 radius 与 antialiasing 控制圆角和平滑边缘：https://doc.qt.io/qt-6/qml-qtquick-rectangle.html
- 用户补充仓库默认源截图：大框来自 ImRadioButton 的 anchors.fill 整行焦点 Rectangle，已移除；键盘焦点通过圆形 indicator 加粗体现。RepositoryRadioButton 覆盖 indicator，因此同步处理。
- 实际仓库对话框截图验收：初始默认源和 Tab 焦点默认源均只显示单选圆圈，无整行矩形。控件预览确认软件渲染 + 125% 缩放仍保留进度圆角。

## IceWhale 应用数据目录
- manifest 使用 QStandardPaths::AppLocalDataLocation，组织名来自 main.cpp / cli.cpp 的 Raspberry Pi。
- 修改组织名会同时改变 Windows/Linux 默认 QSettings 命名空间；macOS 设置主要使用组织域名。需要保留现有设置并迁移清单缓存。
- 统一 initializeApplicationIdentity() 初始化 GUI/CLI：IceWhale 组织名用于新数据目录，保留旧 organizationDomain 以兼容 macOS 现有偏好设置；Windows/Linux 在首次启动复制旧设置且不覆盖新值。
- 首次启动复制 manifest-*.json（排除符号链接），保留原件，已有目的文件不覆盖；复制失败会在下次启动重试。
- 用户将最终组织名更正为 IceWhaleTech；迁移优先使用较新的 IceWhale 数据，其次补充 Raspberry Pi 数据，目的地已有内容不覆盖。迁移标记同步更名以兼容已运行 IceWhale 版本的 macOS。
- 最终应用身份为 IceWhaleTech / zimaspace.com；macOS 旧偏好设置改为显式 QSettings 读取 raspberrypi.com，并跳过旧 migration 标记，避免影响新迁移完成状态。PlatformHelper 字体缩放改读当前应用设置。

## 擦除确认弹窗
- 当前把设备名拼进整段红色标题，倒计时期间按钮整行隐藏，造成信息密集和无操作的大块空白。
- 将其拆成独立 WriteConfirmationDialog：警告图标与短标题、独立设备卡、不可撤销提示和常驻操作区；取消始终可用，确认保持 2 秒延迟。
- 弹窗警告图标缩为 24px（随文字缩放），直接与标题放在同一行，无背景容器；说明缩进与标题对齐。设备卡复用 ic_usb_40px.svg。

## 应用选项与内容仓库弹窗
- 现有布局使用居中标题、粗体选项、大间距及居中版本号，内容层次较弱；Repository 的自定义输入集中在选项后，未紧贴选中的来源。
- 计划统一 480px 自适应白色圆角弹窗，内容分组、简短说明、40px 操作按钮；较大字体/展开内容使用中部滚动，底部操作保持可见。
- 保留来源单选圆圈，不恢复先前移除的整行蓝色焦点边框。
- 首轮隔离组件预览：普通窗口底部卡片被内容区裁切，需进一步压缩间距；保存、取消、重开、URL 校验及写入时禁用切源均通过。
- 最终中文/英文隔离预览通过，普通字号下所有设置完整显示；150% 字号下内容可滚动，焦点自动定位，底部操作保持可见。仓库单选仅圆圈着色，未恢复整行高亮。

## 禁用警告确认弹窗
- 目前内嵌在 AppOptionsDialog 中，使用基础灰色弹窗、整段富文本和蓝色确认按钮。改为与擦除确认一致的白色面板、独立警告说明、系统盘保护说明卡以及红色确认按钮，保留取消回退及确认逻辑。
- 保留原有禁用逻辑，默认聚焦“保留警告”；取消/Escape 恢复开关并返回焦点，确认后才设置临时禁用标记。普通/150% 中英文预览完整显示。

## 弹窗按钮高度统一
- 公共 ImButton / ImButtonRed 使用 Style.buttonHeightStandard（32px），此前新增弹窗覆盖为 Style.scaled(40)。本次将应用选项、仓库、擦除确认、禁用警告确认的操作按钮统一为公共高度。

## 通用错误弹窗
- main.qml 中的错误弹窗按长文本隐式宽度扩展，说明使用 StyledText，磁盘权限错误通过 <br> 分隔原因和建议。
- 将其提取为独立 ErrorDialog，固定自适应宽度、灰色详情卡和可滚动内容，保留富文本及换行兼容；使用“知道了”明确关闭动作，按钮保持 32px。
- 新错误弹窗在 680×450 窗口和 150% 字号下完整显示权限提示；长内容可以滚动到底部，操作区固定可见，原错误文本和格式保留。

## 默认选择与交互优化实施
- 设备与 OS 列表当前不自动选首项；OS 已支持 imager.default_os。
- 本地 cf/ 清单仅 Intel/AMD PC，推荐稳定版在第二项，首项为 beta，不能按列表第一项默认选择。
- 已保存语言仍触发语言页；空设备提示 opacity=0；取消写入把进度写成 100；禁用警告立即改全局状态；空格选中后自动跳页，均已定位。
- 实施中发现 OSListModel::markFirstAsRecommended 会清除仓库原推荐标记，再把首项标为推荐，可能把 beta 标为推荐；需修正推荐模型而不只设置默认索引。
- selectNamedOS 使用 model.get，但 OSListModel 尚未暴露 get；新增明确的取行接口，避免默认选择依赖不存在的方法。

- 推荐策略已改为：稳定的 imager.default_os → 明确推荐的稳定镜像 → 版本号最大的稳定 ZimaOS。测试版、目录和内置操作不参与默认推荐；无明确推荐的第三方仓库保持未选择。
- getFilteredOSlistDocument 即使尚未加载仓库也会附加“擦除/自定义”，因此硬件模型必须通过 hasOsListData 区分加载中与已加载但没有设备分类。无分类/唯一分类可直接进入系统选择，多分类保留选择页。
- OS URL 与存储设备路径分别记录真实选择，列表 currentIndex 只代表键盘游标。返回或刷新仅恢复游标，不重复 setSrc；同名但 URL 不同的镜像也会清理下游选择。
- 取消自定义文件选择保留先前镜像；双击系统盘仍走名称确认；写入取消时忽略后续进度/收尾事件，保留实际进度。
- 本机 Qt 未安装 QtTest QML 模块，交互回归改用隔离 QQmlApplicationEngine、模拟后端及 QKeyEvent，未操作真实磁盘或用户设置。

## 存储页提示叠层
- 空状态目前依赖 !hasValidStorageOptions，只读设备可见时仍会显示空状态并覆盖列表。应单独统计可见设备，只读提示放在列表外。
- 取消系统盘筛选时先显示列表再打开弹窗，确认操作为空；改为确认窗口关闭后应用筛选。设备模型同数量更新也需要刷新状态。
- 交互回归发现 ImCheckBox 的键盘/辅助功能调用 toggle() 不发出 toggled 信号；筛选确认改为统一处理 checkedChanged，并为已确认的修改设内部标志，防止键盘绕过或重复弹窗。
- 已通过普通与 150% 字号预览：新弹窗使用 480px 自适应白色面板、警告标题、灰色说明卡与固定 32px 按钮；确认后的 Overlay.overlay 处于不可见状态，列表空状态也隐藏。

## 格式化与本地镜像入口
- QML 与原生文件选择器均支持 IMG/ISO/WIC/ZIP/GZ/XZ/ZST；旧描述和图标仍强调 .img，格式化描述仅指 USB。改为“格式化设备”和“使用本地镜像”，设备重置/文件内磁盘图标不包含格式文字。
- USB 保留通用三叉符号，改为与格式化/镜像文件一致的深灰色、圆角端点与 2.2px 描边；40px 列表和 28px 确认卡片均已核对，不限定为 U 盘外形。

## macOS 原生窗口
- main.qml 对所有平台使用 FramelessWindowHint，红黄绿按钮由 Rectangle/Canvas 模拟，绿色按钮只调用 showMaximized；因此没有 NSWindow 原生标题栏及绿色按钮菜单。
- Qt 官方 WindowFullscreenButtonHint 可启用 macOS 原生全屏按钮；Qt.Window 可恢复标准系统装饰。采用常规原生标题栏，让拖动、双击和窗口管理由系统处理，无需添加 Objective-C 私有接口。
- 参考：https://doc.qt.io/qt-6/qt.html#WindowType-enum；https://support.apple.com/en-gb/guide/mac-help/mchlef287e5d/mac。平铺仍遵循窗口最小尺寸和 macOS 的窗口管理设置。
- 隔离预览确认 NSWindow styleMask=15（标题栏、关闭、最小化及缩放）、collectionBehavior=128（FullScreenPrimary，未禁止平铺），三个标准 NSButton 均存在、启用且可见；原生标题栏高度 32px，内容最小尺寸保持 680×420。
- 用户要求移除标题栏背景后，加入 ExpandedClientAreaHint 和 NoTitleBarBackgroundHint；ApplicationWindow 自动将内容放入安全区域，背景延伸到窗口顶部。最终 NSWindow styleMask=32783，titlebarAppearsTransparent=true，保持原生按钮及 FullScreenPrimary。参考：https://www.qt.io/blog/expanded-client-areas-and-safe-areas-in-qt-6.9。
- 透明扩展客户区缺少显式拖动入口。在 ApplicationWindow.background 的顶部安全区域加入 MouseArea，左键按下调用 startSystemMove；高度跟随 topPadding，不占用内容区，原生 NSButton 仍在 Qt 内容视图上方处理点击。参考：https://doc.qt.io/qt-6/qwindow.html#startSystemMove。
- 上述 background 方案实测无效：ApplicationWindowContentControl 覆盖整个窗口并拦截事件。隔离事件回归在 (340,16) 注入同样的 Qt 鼠标按下/松开，背景方案触发次数为 0，header 方案为 1。最终拖动区域放在 ApplicationWindow.header，高度取 window.SafeArea.margins.top，保留原生安全间距和透明背景，不叠加额外标题栏行。

## 全语言 i18n 审计
- 应用从打包的 QM 自动枚举语言，共 27 个 TS 目录。用户确认覆盖全部语言，并清除不再使用的条目。
- lupdate 同步后新增文案和清除过时文案；补充串口选项与组合框错误提示后，每种语言共有 686 个活动条目。串口显示文本与配置值已分离，避免翻译后破坏设备配置。
- 英文使用源文案补齐；简体中文补齐 127 条，繁体中文补齐 597 条（复用中文并转换台湾用语，保留已有繁体翻译）。
- 在相同上下文和品牌归一化后复用上游已有有效译文：https://github.com/raspberrypi/rpi-imager/tree/main/src/i18n。
- 网络翻译测试不可用（Google 429、Bing 空响应、Lingva 403），改为本地 M2M100 辅助翻译，模型与运行依赖仅放在 /tmp，不引入产品依赖。模型来源：https://huggingface.co/michaelfeil/ct2fast-m2m100_418M。

- M2M100 抽查不合格，已撤回其生成内容并改用本地 NLLB-200。来源：https://huggingface.co/JustFrederik/nllb-200-distilled-600M-ct2-int8。按钮、串口模式、取消中、存储空状态及擦除风险提示另行逐语言编辑；不将模型输出等同于母语校对。
- 本次 lupdate 共移除 609 个已不被源码引用的条目（跨 27 个目录累计）；保留平台条件、调试和设备定制页面仍引用的条目。
- 最终覆盖率：27 个语言目录 × 686 个活动条目 = 18,522 条，空译文/未完成/废弃条目均为 0。Qt lcheck、lrelease、QTranslator 逐条比对和 macOS 构建通过。新增 tools/check_translations.py 与 doc/translations.md，后续更新可复用同一套检查。

## 标题文字拖动
- 原生测试窗口复现：从标题文字拖动，窗口位置保持 (3500,510)。命中视图为 NSTextField，mouseDownCanMoveWindow=true，但 NSWindow.movableByWindowBackground=false；空白区域命中 QNSView，需要已有 QML header 处理。将验证启用原生背景拖动后是否覆盖文字，同时检查正文不跟随拖动。
- Qt 6.11.1 官方源码 startSystemMove 使用 performWindowDragWithEvent；读取 qcocoawindow_manager.mm 首次路径错误（404，实际名无下划线），GitHub API 目录枚举限流（403），改为读取官方原始 CMakeLists 定位。
- 最终采用 NSWindow.movableByWindowBackground = YES，保留 ExpandedClientAreaHint、透明标题栏与 QML header。标题 NSTextField 及其原生祖先 mouseDownCanMoveWindow 均为 true，正文 QNSView 为 false，原生拖动开关补齐后由 AppKit 决定拖动区域，不拦截鼠标事件。参考：https://developer.apple.com/documentation/appkit/nswindow/ismovablebywindowbackground 与 https://developer.apple.com/documentation/appkit/nsview/mousedowncanmovewindow。
- 自动拖动验证存在边界：CUA 发出了原生鼠标按下/拖动/抬起，但普通原生标题栏（已去掉 ExpandedClientAreaHint 的对照窗口）也没有位置变化。因此不能用本轮 CUA 结果声称真实拖动通过；事件监控/手工转发尝试全部撤回，产品中不含这些逻辑。

## 标题栏双击最大化
- 现有 QML 标题栏只在按下时开始系统拖动，没有双击最大化逻辑；原生标题文字位于 QML 之上，也无法通过 QML MouseArea 处理。
- 本轮新增窗口生命周期内的 AppKit 本地双击监听：仅处理目标窗口顶部安全区域内的 Qt 标题栏或原生只读标题文字，切换最大化/还原；原生按钮和正文不匹配，全屏时不处理。非 macOS 自绘标题栏补充 QML 双击处理。
- 首次隔离测试中，原生标题双击通过，但 QML 双击与按下启动系统拖动发生冲突，空白区域未最大化。将 macOS 两个区域统一提前在原生事件路径处理后回归通过。

## 跨平台原生窗口（2026-09-29）
- 现有 main.qml 仅 macOS 使用原生窗口；Windows/Linux 使用无边框和 QML 模拟按钮，Windows 另有 8px 人工阴影边距。
- Qt 6.9+ ExpandedClientAreaHint / NoTitleBarBackgroundHint 官方支持 macOS 和 Windows，Linux 不在支持列表。Linux 系统标题栏的圆角、居中和背景由窗口管理器/装饰插件决定，不能跨 GNOME/KDE、X11/Wayland 一概保证。
- Qt Windows 后端源码需要核对是否真正保留系统按钮，以及标题区域命中和 SafeArea 行为。读取独立 qwindowstitlebar.cpp 返回 404，实际实现位于 qwindowswindow.cpp，已下载 v6.11.1 供审计。
- 参考：https://www.qt.io/blog/expanded-client-areas-and-safe-areas-in-qt-6.9；https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/ui/apply-rounded-corners。
- Windows 11 原生圆角在最大化/贴靠等状态下按系统规则关闭，Windows 10 本身无相同的 DWM 圆角接口。
- Windows 改为公开 Win32/DWM API：保留 WS_CAPTION / WS_THICKFRAME，通过 WM_NCCALCSIZE 仅扩展顶部客户区，DwmDefWindowProc 保留原生按钮，HTCAPTION 提供拖动、双击、系统菜单和还原拖动。避开 Qt ExpandedClientAreaHint 的平台自绘按钮，不依赖 Qt 私有 API。
- Qt qWindowsWndProc 明确捕获用户覆盖 WM_NCCALCSIZE 后的矩形，更新 frame margins；因此侧边和底边保留 DefWindowProc 计算，上边扩展方案可与 QPA 几何同步。
- Windows 使用原生 DPI 指标和 DWM 按钮范围提供 QML 预留区；Linux 使用普通 Qt.Window 装饰，禁止第二行应用标题。macOS 保留现有透明原生标题栏路径。
- 最终实现保留 QML onClosing 写入确认，并让 Windows caption/button hit test 进入原生消息路径。原生按钮字色根据实际页面底色设置，避免深色系统主题在浅色页上使用白色图标。
- 布局分支检查在 macOS 通过临时平台常量与模拟 DWM 指标进行，只验证 QML 几何和事件声明；没有冒充 Windows/Linux 原生运行验证。

## Linux macOS 风格补充
- 用户已改选统一 macOS 风格。Linux 改为透明无边框窗口与左侧红黄绿自绘按钮、居中标题、统一圆角表面和轻阴影；不再声称为系统原生按钮。
- 自绘标题栏的拖动延迟至超过系统拖动阈值，避免按下即进入系统拖动吞掉双击；边缘/角落调用 startSystemResize，以支持 Wayland 系统交互。
- 最大化/全屏去掉阴影边距与外圆角，全屏隐藏自绘标题栏。Windows DWM 源码不变，仍保留系统阴影。
- BaseDialog 原先无条件为 Windows 保留旧 8px 人工阴影边距，与上一轮原生 DWM 转换不符；改为读取所属窗口的实际阴影边距与圆角，Linux 弹窗遮罩也保持一致。

## Linux Ubuntu 按钮
- 用户进一步指定 Ubuntu 风格按钮。参照 Ubuntu Yaru 官方 GTK 样式：中性色圆形背景，前景色 10%/15%/25% 对应普通/悬浮/按下；失焦移除背景并减弱图标。按钮按最小化、最大化/还原、关闭顺序放右侧。
- 参考 https://github.com/ubuntu/yaru/blob/master/gtk/src/default/gtk-3.0/_tweaks.scss。尝试读取该目录 assets/window-maximize-symbolic.svg 返回 404；本实现自行绘制简单几何图标，不复制主题素材。
- 最大化时图标切换为叠放方框；标题按实际按钮组宽度对称避让，保持窗口居中。

## Windows 11 按钮被背景覆盖
- DWM 扩展框架要求其下方像素 alpha=0；此前窗口 clear color 和页面背景均不透明，原生命中成功不能证明按钮显示。参考：https://learn.microsoft.com/en-us/windows/win32/dwm/customframe。
- Qt 官方 6.11.1 QWindowsWindow::setWindowLayered 在有原生框架、opacity=1 时不会仅因 alpha buffer 增加 WS_EX_LAYERED；保留系统阴影/圆角所需样式。QQuickWindow 的透明 clear color 请求 alpha buffer，D3D11 的 alpha swapchain 使用 DirectComposition。
- 使用共享 WindowFrameBackground 为 DWM 实测按钮范围留空；弹窗遮罩同样留空；非 alpha/软件后端或缺少有效按钮范围时保留标准系统标题栏。
