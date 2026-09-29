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
