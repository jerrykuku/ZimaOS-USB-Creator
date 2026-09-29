# Progress Log

## Session: 2026-09-02

### Phase 1: Preserve Current Work
- **Status:** complete
- Actions taken:
  - Fetched `upstream/main` without merging it.
  - Measured divergence and inspected the current dirty worktree.
  - Committed implementation changes as `0d827864`.
  - Created `backup/pre-upstream-sync-20260902` at the preserved fork head.
- Files created/modified:
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

### Phase 2: Merge Upstream
- **Status:** complete
- Actions taken:
  - Preparing to merge `upstream/main` with a non-fast-forward merge commit.
  - Standard merge attempted and produced broad conflicts across fork-customized files; it will be aborted and retried with `-X ours`.
  - Re-ran the merge with `-X ours`; clean upstream changes were applied and conflicting fork hunks were retained.
  - Resolved six modify/delete conflicts by keeping the fork's deleted files and preserved the renamed ZimaOS post-install script.
  - Created merge commit `43149125`.

### Phase 3: Verify
- **Status:** complete
- Actions taken:
  - Starting a clean configure/build verification of the merged macOS target.
  - Fixed merge integration issues in `main.cpp`, `downloadthread.cpp`, and the bundled libusb/clipboard build.
  - Rebuilt successfully with `ninja -C build zimaos-usb-creator`.
  - Fixed live-mode QML type/property mismatches (`ImageWriter` injection, app-options signal, missing passwordless-sudo dialog registration, and dialog writer property).
  - Verified `./mac-dev.sh --qml-live` now stays running, loads the development source directory, and reaches network/OS-list initialization. Qt emits non-fatal required-property warnings from the compiled StackView components.

### Phase 4: Handoff
- **Status:** complete
- The upstream sync and integration repairs are committed locally and remain unpushed.

### Session: UI startup and layout fixes
- Restored the initial device-selection page so network availability does not cause an automatic tab jump.
- Made list scrollbars appear only when content exceeds the viewport.
- Removed the macOS Monaco font fallback, restored missing sidebar metrics, and made OS delegates size to wrapped content.
- Replaced the checkbox indicator with a compact square indicator without the external focus halo.
- Rebuilt the macOS target successfully.

### Session: Loading indicator import
- Added the missing `QtQuick.Controls` import required by the device-page `BusyIndicator`.
- Rebuilt and launched `./mac-dev.sh --qml-live` successfully; the app fetched the manifest and remained running.

### Session: Initial page alignment
- Fixed `StackView.initialItem` to use the device-selection component whenever language selection is not requested, matching `currentStep` and preventing OS content from appearing under the Device tab.
- Rebuilt the macOS target successfully.

### Session: Device metadata loading
- Confirmed device types come from the remote manifest's `imager.devices` array.
- Added an explicit loading state to `DeviceSelectionStep`; the list remains hidden until `HWListModel.reload()` succeeds, while network failures retain the retry state.
- Rebuilt the macOS target successfully.

### Session: Local manifest cache
- Added a per-repository JSON manifest snapshot under macOS application-local data.
- Startup reads the snapshot before network access; successful online responses replace it atomically and still emit the normal model-refresh signal.
- Repository changes load the matching snapshot, while malformed snapshots are ignored safely.
- Rebuilt the macOS target successfully.

### Session: Settings-style layout
- Applied the requested `#f5f5f5` window background and 8px outer/content spacing.
- Restyled the sidebar as a white bordered panel with 8px padding, active/hover states, and 160px navigation items.
- Removed the right-side enclosing frame and the options icon border; wizard content remains height-adaptive with fixed header/footer layout.
- Rebuilt the macOS target successfully.

### Session: Eight-issue remediation plan
- Reviewed the supplied screenshot and recorded eight concrete UI findings in `findings.md`.
- Replaced the previous sync-focused plan with an eight-phase implementation and verification plan in `task_plan.md`.
- No product source files were changed in this planning-only step.

### Session: Eight-issue remediation implementation
- Added a frameless custom macOS title bar with drag, close, minimize, and maximize controls.
- Separated wizard title/footer from the framed flexible content area.
- Improved sidebar heading scale and disabled-label contrast.
- Improved disabled button background/text contrast and made the settings icon background transparent except for hover/focus.
- Verified `ninja -C build zimaos-usb-creator` and launched `./mac-dev.sh --qml-live`; cached manifest loaded and the app remained running without QML load errors.

### Session: Supplementary layout requirements
- Added the four new alignment and sizing requirements as Phase 9 in `task_plan.md`.
- Recorded the additional screenshot findings in `findings.md`.
- No source files changed in this planning update.

### Session: Second screenshot review
- Added the 12 newly reported visual issues to `findings.md`.
- Added Phase 10 for the second-round UI fixes and Phase 11 for priority acceptance in `task_plan.md`.
- No product source files changed in this planning update.

### Session: Unified rounded application surface
- Reworked the frameless window so Title Bar and main content share one clipped rounded surface instead of appearing as separate rounded panels.
- Kept the title-bar divider inside the unified surface and preserved window controls/dragging.
- Built and launched QML live successfully; cached manifest loaded without QML component errors.

### Session: Spacing and title-bar refinement
- Removed the Title Bar bottom divider.
- Set sidebar/content layout spacing to `16px`.
- Set the step layout right edge to `8px`, aligning the content frame and bottom action area.
- Rebuilt the macOS target successfully.

### Session: Corrected spacing and title-bar corners
- Removed the extra step-level left inset that made the sidebar/content gap exceed the requested `16px`.
- Applied rounded corners to the custom Title Bar within the shared window surface.
- Rebuilt the macOS target successfully.

### Session: Navigation and content inset correction
- Restored the original sidebar item vertical positions; the sidebar heading now uses a visual-only translation.
- Removed extra top/bottom inset from device and OS delegates.
- Unified the step content frame insets to `8px` on all four sides.
- Rebuilt the macOS target successfully.

### Session: Writing progress and title bar polish
- Hid the Writing step subtitle in all states.
- Replaced the progress bar styling with a rounded theme-blue track/fill.
- Simplified the custom title bar text to the application name only.
- Added hover glyphs for close, minimize, and maximize traffic-light controls.
- Rebuilt the macOS target successfully.

### Session: Sidebar gap and OS item spacing
- Removed the extra step-level left inset and reduced layout spacing so the sidebar/content gap no longer expands unexpectedly.
- Restored `8px` top/bottom card insets for OS items and added `8px` ListView spacing between items.
- Rebuilt the macOS target successfully.

### Session: Dialog margins and writing confirmation
- Standardized BaseDialog outer/content margins to `16px`.
- Centered the pre-write countdown text.
- Set shared button horizontal padding to `12px` for long labels.
- Rebuilt the macOS target successfully.

### Session: Global layout design tokens
- Committed the current UI state as `96e4a540` before refactoring.
- Added shared page, panel, card, title-bar, border, inset, and icon-size tokens to `Style.qml`.
- Migrated main window, WizardContainer, WizardStepBase, and shared button components to use the tokens.
- Ran `git diff --check`; no whitespace errors. Build was intentionally not run in this refactoring step.

### Session: QML live source resolution
- Diagnosed that only `main.qml` was loaded from `src`; QML types from the `RpiImager` module still resolved to compiled `qrc:/qt/qml` files.
- Added a live-mode `QQmlAbstractUrlInterceptor` in `src/main.cpp` to redirect module QML URLs to the local source tree.
- Rebuilt and launched `./mac-dev.sh --qml-live` successfully; source mode starts without QML load errors.

### Session: OS card height consistency
- Unified OS delegate minimum height and card padding so multi-line metadata, including release dates, remains visible.
- Removed inconsistent card top/bottom inset while retaining list spacing between cards.
- Rebuilt the macOS target successfully.

### Session: Content-driven OS cards
- Removed the oversized `120px` OS card minimum.
- OS cards now size from row content with a compact `72px` floor and uniform `8px` vertical/horizontal padding.
- Rebuilt the macOS target successfully.

### Session: Fixed sidebar/content gap
- Restored the main `RowLayout` gap to a fixed `16px`.
- Removed the competing step-level left inset, so the inter-panel distance is controlled in one place only.

### Session: Unified panel corners
- Unified sidebar and right content outer corner radius through `Style.panelRadius`.
- Removed the sidebar's extra shadow rectangle.
- Build was intentionally not run.

### Session: Button radius token
- Added `Style.buttonRadius` with a fixed `8px` value.
- Updated shared buttons, settings button, and confirmation cancel button to use the dedicated token.
- Build was intentionally not run.

### Session: App options dialog margins
- Updated `AppOptionsDialog.qml` to use the shared `Style.popupMargin` for content, sizing, and button-row margins instead of local `cardPadding` values.
- Corrected button-row width/height calculations for the new 16px margins.
- Ran `git diff --check`; no whitespace errors. Build was not run.

### Session: Removed nested app-options inset
- Removed duplicate inner margins from the options and button sections.
- The dialog now relies on the single `BaseDialog` 16px outer content margin.
- Build was not run.

### Session: Semantic Style token grouping
- Added canonical semantic color, spacing, and geometry token groups to `Style.qml`.
- Retained legacy aliases for compatibility while migrating pages incrementally.
- Migrated main window and wizard surface references to the canonical names.
- Ran `git diff --check`; build was not run.

### Session: macOS launch compatibility investigation
- Started auditing the current macOS bundle and distribution scripts for failures affecting only some machines.
- Added Phase 13 covering architecture, deployment target, signing, notarization, packaging, and Gatekeeper verification.

### Session: arm64-only distribution target
- Narrowed distribution defaults and bundle validation to arm64 per the requested hardware scope; x86_64/Universal support is no longer required.
- Shell syntax and `git diff --check` passed. Existing app bundle validation found every Mach-O payload contains arm64.
- `ninja -C build zimaos-usb-creator` was blocked because the existing build directory is missing `CMakeFiles/VerifyGlobs.cmake`; a direct CMake configure was also blocked by the directory's existing Unix Makefiles generator. A clean separate build directory is required for final compile verification.

## Test Results
| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| macOS build | `ninja -C build zimaos-usb-creator` | Successful app bundle | Build and Qt deployment completed successfully | PASS |

## Error Log
| Timestamp | Error | Attempt | Resolution |
|-----------|-------|---------|------------|
| 2026-09-02 | Standard upstream merge conflicts | 1 | Retry with `-X ours` to preserve conflicting fork changes |

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase 4: Handoff |
| Where am I going? | Commit, backup, merge upstream, resolve conflicts, verify build |
| What's the goal? | Synchronize upstream while preserving fork changes |
| What have I learned? | See findings.md |
| What have I done? | Preserved local work, merged upstream, repaired integration issues, and verified the macOS build |

## Session: 2026-09-22 恢复内容存储库
- 已定位删除提交 `0d827864`，开始恢复历史对话框并适配当前接口。
- 查找时尝试的 RepoSourceDialog.qml 不存在；历史中的实际名称为 RepositoryDialog.qml，当前已删除。BaseDialog 位于 qmlcomponents。
- 初次构建通过，UI 入口、URL 校验、Escape 取消后重开均通过。发现并修复旧原生文件选择信号与 OS 页面冲突。
- UI 自动化遇到 elementHasNoFrame，改用截图坐标定位设置按钮。
- 最终构建 `cmake --build build --target zimaos-usb-creator -j 8` 成功；git diff --check 通过。
- 最终 UI 验证通过：本地 JSON 浏览回填、应用后标题显示 zimaos-manifest.json、重新打开后读取当前源、切回默认 ZimaOS 源并重置向导。测试结束时已恢复默认源。
- 恢复简体/繁体中文文案；URL 校验和取消状态已实测。未执行磁盘写入；未测试 Windows/Linux 运行时。

## Session: 仓库设置样式调整
- 完成对齐、紧凑无背景 radio、32px 圆角输入框及浏览控件组，开始界面验证。
- macOS 构建通过；实际截图确认开关/编辑/保存按钮右对齐、radio 无浅蓝色背景、文件组共享圆角外框与分隔线、URL 同高圆角。未应用仓库变更，窗口停留在文件组预览。
- git diff --check 通过。本次样式修改仅涉及 ImOptionPill.qml 和 RepositoryDialog.qml。

## Session: 2026-09-28 写入圆角与 Windows 状态背景
- 已读取现有计划和进度，检查公共按钮、复选框、单选框与写入进度实现。
- 正在区分项目显式焦点填充和 Material 默认状态背景。
- 已完成样式修改并注册 ImProgressBar；正在构建和准备不访问磁盘设备的控件预览。
- 工具探测发现本地没有 QtTest QML 模块；改用 qml 运行器预览和直接状态断言。
- 首轮 macOS 构建通过。临时 QML 预览的绝对路径导入被运行器拒绝，已改用 file: URL。
- 预览的状态断言正常；ApplicationWindow 原生 contentItem 不支持 grabToImage，截图目标改为 QML 自建容器。
- 控件预览通过：0%、0.1%、1%、25%、99.9%、100%，RTL，未知总量动画及减少动态效果；普通按钮焦点保持中性底色、键盘边框可见；单选键盘焦点仅加粗圆圈。
- 已在真实应用打开仓库对话框并按 Tab 聚焦默认来源，截图确认普通和键盘焦点状态均无整行高亮框。
- 软件渲染 + 125% 缩放的同一组控件断言通过；真实应用日志没有 QML 警告或错误。未执行真实磁盘写入，当前环境无 Windows 原生运行时。
- 最终增量构建 cmake --build build --target zimaos-usb-creator -j 8 成功（退出码 0），包含新增仓库焦点修复；git diff --check 通过。全部本次请求完成，Windows 原生验证留作平台限制。

## Session: IceWhale 应用数据目录
- 已定位 GUI 和 CLI 的组织名初始化，正在实施兼容迁移。
- GUI/CLI 初始化已更新；构建编译已通过，正在部署 Qt 并验证实际启动路径。迁移前旧目录有 4 个 manifest，新目录为 0。
- macOS 构建通过，CLI --version 启动通过；4 份旧 manifest 已逐个 SHA-256 比对确认原样复制到 IceWhale，新旧内容一致、旧文件保留。GUI 启动日志确认 Loaded cached OS manifest 使用 IceWhale/ZimaOS USB Creator 路径；git diff --check 通过。

## Session: IceWhaleTech 命名更正
- 完成初始化和旧目录迁移更新，开始构建与实际启动验证。
- 构建、CLI --version 与 GUI 启动通过。4 份清单已校验完整复制；启动日志确认从 IceWhaleTech/ZimaOS USB Creator 加载 manifest。git diff --check 通过。

## Session: zimaspace.com 域名更正
- 已更新应用身份和旧设置迁移，正在构建和核对偏好设置。
- 独立设置迁移探针改用当前 Qt 的动态库布局，验证实际旧域名读取与重复启动行为。
- macOS 构建及 CLI 启动通过。独立 Qt 探针验证当前身份为 IceWhaleTech/zimaspace.com，旧域名设置迁移保留、新设置不被覆盖、旧设置未改写、重复初始化稳定。新偏好设置为 com.zimaspace.ZimaOS USB Creator.plist，缓存路径仍为 IceWhaleTech/ZimaOS USB Creator。git diff --check 通过。

## Session: 擦除确认弹窗美化
- 已检查 WritingStep 与 BaseDialog，开始独立弹窗实现。初次翻译路径 src/translations 不存在，正在按实际文件定位。
- 新建 WriteConfirmationDialog 和警告 SVG，已接入 WritingStep；取消始终可用，确认按钮稳定宽度并显示倒计时，保留 2 秒延迟及屏幕阅读器行为。已补充英文、简体、繁体中文。
- 首轮预览发现 Dialog.title 触发默认标题栏，出现重复标题和底部裁切；已显式禁用默认 header，保留自定义标题与无障碍名称。预览截图改为按实际控件状态捕获。
- 150% 字体预览发现确认按钮宽度未随文本充分增长；改为同字体隐藏标签预留实际宽度，并缩放按钮最小尺寸，复核不省略倒计时文字。
- 中文和英文预览通过：初始确认禁用、2 秒解锁、弹窗/按钮尺寸稳定、Escape 取消、重新打开重置、屏幕阅读器绕过延迟和确认信号只触发一次；150% 字体和长设备名完整显示。预览在隔离组件中执行，没有接入磁盘写入。
- 中文预览已保存至 build/ui-previews/write-confirmation-{ready,waiting,long-name}.png。
- 最终 macOS 增量构建成功（退出码 0）；git diff --check 和三种语言 TS XML 解析通过。本次美化完成，未执行真实擦除/写入。

## Session: 擦除弹窗微调
- 已完成单个 QML 文件的图标和标题排版修改，开始复用隔离预览验证。
- 已确认截图中警告图标无背景、与标题垂直居中，说明文字与标题左边缘对齐，设备卡使用 USB 图标。原有倒计时/取消/确认及 150% 字体预览通过。
- 最终 macOS 构建通过，git diff --check 通过；更新后的预览已保存至 build/ui-previews/write-confirmation-ready.png。

## Session: 应用选项与内容仓库优化
- 已检查两个弹窗、设置行公共组件及原有保存/切换逻辑，开始布局修改。
- 已完成两个弹窗布局；英文 TS 缺少 RepositoryDialog 上下文，补充该上下文后再生成翻译。
- 已收紧普通字号的行距与操作区，新增 ImScrollView 使大字号下键盘焦点自动滚入可视区域；补充中英文新文案。正在做最终预览和构建。
- 中文/英文预览验证通过：保存选项、取消不保存、重开恢复、文件/URL 输入、无效 URL 禁用、写入时禁用切源、同一来源不重复重置。150% 字体下键盘可聚焦并滚动到编辑按钮和 URL 输入。已保存 build/ui-previews 下预览。
- 最终 macOS 构建成功（退出码 0）；git diff --check、三种语言 TS XML 与重复文案检查通过。当前两项界面优化完成。

## Session: 禁用警告确认弹窗优化
- 已检查原有确认/取消处理与前面弹窗样式，开始修改内嵌确认弹窗。
- 首轮隔离预览的控件查找脚本未兼容 QML data 列表，已改为索引遍历；该错误发生在预览脚本，应用组件正常加载。
- 中文/英文普通与 150% 字号预览通过；确认、取消、Escape、重复打开和无障碍初始焦点检查通过。macOS 构建成功（退出码 0），构建目录 QML 与源码一致，TS XML 和 git diff --check 通过。预览已保存 build/ui-previews/disable-warnings.png。

## Session: 弹窗按钮等高
- 已将四处弹窗的 8 个操作按钮改为公共 32px 高度，开始核对预览与构建。
- 隔离预览实测按钮高度与导航共用 32px 标准，普通/150% 字号及原有交互检查通过。macOS 构建、git diff --check 通过，预览图已更新。

## Session: 通用错误弹窗优化
- 已定位 main.qml 错误弹窗及 macOS 权限错误内容，开始样式调整。
- 中英文隔离预览通过：真实权限错误文案、短错误、长路径、富文本/换行及 150% 字号；关闭/Escape、重开重置滚动、屏幕阅读器焦点和 32px 按钮检查通过。预览已保存 build/ui-previews/error-permission.png。
- 最终 macOS 构建成功（退出码 0）；main.qml 与 ErrorDialog 的构建副本与源码一致，TS 翻译和 git diff --check 通过。本次错误弹窗优化完成。

## Session: 取消写入按钮改为红色
- 公共主按钮增加 destructive 样式，写入步骤仅在取消写入时启用；写入、跳过验证、完成操作保持蓝色，尺寸沿用 32px。
- 按钮配色预览通过，取消写入为红色；macOS 构建成功（退出码 0），git diff --check 通过。

## Session: 执行默认选择与交互优化
- 已按用户要求提交当前所有非忽略修改：36294147。cf/ 按既有 .gitignore 保持忽略，不部署。
- 已创建实施计划，开始检查模型角色和向导导航依赖。

- 已完成默认稳定版、单设备/无设备分类跳步、推荐/测试版标签、已保存语言复用、选择状态与键盘游标分离、可见存储空状态、下载/取消反馈及设置保存事务。
- 增加 imageselectionpolicy_test.cpp 并接入 CTest；QtCore 独立编译运行通过，覆盖 beta 首项、显式默认、版本号比较、第三方仓库、空列表和内置动作排除。
- 隔离 QML 回归通过：单/多/零硬件分类；OS 默认、方向键/空格/Enter、刷新/本地镜像恢复、取消文件选择；存储空/只读/筛选/失败状态、明确选择、系统盘双击确认；下载/写入/验证及取消中的重复操作与延迟事件；警告开关确认/取消/Escape/保存/重开。
- 已检查普通与 150% 镜像列表截图、存储空状态、写入和取消截图；预览与模拟后端位于 build/ui-previews/ux*。旧有 QML 属性覆盖提示仍存在，本次流程未出现新的运行错误。
- 最终增量 macOS 构建成功（退出码 0），四份翻译 XML 与 git diff --check 通过。计划全部完成；本轮新改动尚未另行提交，保留工作区差异供审阅。Windows 原生运行与真实磁盘写入未实测。

## Session: 通用存储提示与显示系统盘弹窗
- 已检查现有筛选弹窗、空状态与模型更新逻辑，继续使用 planning-with-files 记录本轮修改和验证。
- 首轮键盘确认回归发现 toggle() 未触发原 onToggled；已统一修改筛选状态入口，继续验证关闭、重开与遮罩清理。
- 通用存储说明与图标已更新，只读设备提示移到列表外，模型 reset/dataChanged/增删与筛选变化均刷新可见/可写状态。
- 隔离交互已通过：确认前系统盘保持隐藏，确认/取消/Escape 后弹窗及遮罩消失，系统盘显示后不叠加空状态，空格切换同样要求确认，禁用警告时直接显示。普通/150% 字号和屏幕阅读器初始焦点检查通过。
- 已目视核对新弹窗、系统盘显示后与只读列表截图；新的英中翻译 XML 有效。
- 英文与中文 150% 字号预览全部通过，确认关闭后截图可见系统 SSD 且无任何遮罩或中央提示覆盖；只读闪存保留卡片，说明位于列表下方。
- 最终 macOS 构建成功（退出码 0），git diff --check 与四份翻译 XML 校验通过。本轮未执行真实磁盘写入，Windows 原生环境未实测。

## Session: 简化存储空状态文案
- 将“所有设备已被筛选隐藏”改为两行直白提示：“未找到可用的存储设备。／请连接存储设备，或取消勾选‘排除系统驱动器’。”同步英中繁体翻译并对齐复选框名称；不修改筛选逻辑。

## Session: 本地镜像入口图标和文案
- 已更新两个 SVG、后端内置列表名称与说明，以及中英文/繁体翻译；离线引导同步指向新的本地镜像名称。开始预览和构建。
- 根据追加要求，将 USB 三叉符号改为统一的 2.2px 圆角描边 SVG；保留 USB 通用语义，设备列表与写入确认复用同一资源。
- USB 预览脚本首次误设只读的 confirmationDelay，已移除并仅在隔离预览中设置 countdown；产品逻辑未修改。
- 已检查中英文及 150% 字号的两项入口，USB 在存储列表、确认弹窗及放大布局中显示正常；SVG/翻译 XML 与 git diff --check 通过。预览位于 build/ui-previews/image-actions*、usb-icon。
- 包含三个新图标的最终 macOS 构建成功（退出码 0）。本轮仅调整入口文案与 SVG 展示资源，没有改变刷写格式支持或磁盘操作逻辑。

## Session: USB 图标改为 U 盘外形
- 按用户要求，将三叉 USB 符号替换为带金属插头和圆角盘体的 U 盘 SVG，保持深灰色与 2.2px 描边。已核对 40px 设备列表及 28px 写入确认卡片预览，资源 XML 和差异检查通过。

## Session: macOS 原生窗口控制
- 已定位无边框窗口与模拟按钮实现，继续使用现有规划文件记录原生标题栏替换和验证。
- main.qml 在 macOS 非嵌入模式启用 Qt.Window 和 WindowFullscreenButtonHint，隐藏自绘标题栏并移除其占位，窗口背景交由系统裁切；其他平台沿用原实现。
- 隔离原生预览复用实际窗口配置和 onClosing 处理：检查 Cocoa 标准按钮及窗口管理标志，通过原生关闭按钮验证写入中的确认拦截，通过最小化按钮验证最小化与恢复。CUA 的系统缩放动作及截图进一步确认窗口可缩放和还原。
- 绿色按钮的 Move & Resize 悬停菜单由系统实现；当前 CUA 无悬停 API，未完成菜单目视验证，不将其记为实测通过。测试应用已关闭，未操作真实磁盘或用户正在运行的应用。
- 最终 macOS 构建成功（退出码 0），git diff --check 通过。

## Session: 原生标题栏去除背景
- 按用户反馈将 macOS 标题栏改为透明，使用 Qt 扩展客户区和无标题栏背景标志，保留系统按钮及自动安全区域。
- 隔离预览检查通过：原生透明背景、FullSizeContentView、顶部安全间距、关闭保护、最小化及恢复。截图确认顶部无独立背景及分隔线，页面内容未与按钮重叠。
- 最终 macOS 构建和 git diff --check 通过；测试窗口已关闭。预览重建时绝对 QML 导入缺少 file: 前缀导致一次加载失败，修正后通过，产品代码不受影响。

## Session: 透明标题栏拖动修复
- 补充顶部安全区域的 MouseArea，通过 startSystemMove 调用系统窗口拖动，保留透明背景及原生控制按钮。
- 隔离预览加载正常，透明原生标题栏、安全间距、写入中关闭保护、最小化及恢复检查通过。macOS 构建退出码 0，git diff --check 通过。
- 实际拖动验收未完成：第一次 CUA drag 未观察到位置变化；后续拖动持续报 noWindowsAvailable，重新选择应用、Raise 和刷新截图后仍无法执行。记录为工具验证阻塞，不声称实际拖动已通过；预览窗口已关闭。

## Session: 透明标题栏拖动事件层级修正
- 用户反馈重新启动 dev 后仍不能拖动。隔离回归成功复现背景层 MouseArea 无法收到按下事件，定位到 ApplicationWindowContentControl 的覆盖和事件拦截。
- 将拖动区域移至 header，高度使用原生 SafeArea 顶部间距。相同坐标 Qt 鼠标事件在修改前触发 0 次，修改后触发 1 次；原生透明背景、关闭保护、最小化与恢复隔离回归通过。
- GUI 验证先遇到自动最小化测试与 CUA 激活竞争、截图超时及 ScreenCaptureKit 错误；关闭预览自动操作并重置 CUA 连接后恢复。最终用 CUA 实际拖动，窗口坐标由 (3500,510) 变为 (3423,508)，确认原生系统移动发生；测试窗口已关闭。
- macOS 构建成功（退出码 0），git diff --check 通过。产品代码仅调整 main.qml 的事件层级，没有增加原生桥接或改变磁盘逻辑。

## Session: 全语言翻译补全与清理
- 用户确认覆盖全部 27 个语言目录，并删除未使用翻译；lupdate 已同步源码并清除废弃条目。新增串口选项和组合框错误提示后，每个目录有 686 个活动条目。
- 保留已有译文，复用上游匹配内容，完成英文、简体中文和繁体中文缺失项。加入 tools/check_translations.py 和维护说明；校验工具的占位符、文件后缀、富文本、废弃项及空译文错误用例已通过。
- 串口显示文字和稳定配置值分离；隔离中文界面验证已通过 Hardware 恢复、Console & Hardware/Console 保存，未修改真实设备。初次预览缺少 FocusableText 模拟模块、未启用 ccRpiAvailable，修正预览配置后通过。
- 在线翻译测试不可用，转用本地模型；M2M100 抽查质量不足，已停止并撤销其草稿，改用 NLLB。首次停止命令未匹配 Python 解析后的进程路径，已按进程 ID 确认终止，并仅清空原缺失项重新生成，保留已有译文和手工补全。
- 常用按钮和三类擦除/系统盘风险文案已编写逐语言人工覆盖；其余缺口正在本地辅助翻译。模型和依赖仅在 /tmp，未加入产品。
- 已逐语言修正主要按钮、禁用警告说明、存储空状态、取消/下载状态及串口选项；另修正抽查发现的格鲁吉亚语异常输出和技术标识误译。
- 德语、日语、希伯来语隔离弹窗验证通过：按钮文字未溢出，确认、取消、Esc、暂存、保存及重新打开行为正常；技术标识校验的正反用例通过。
- 全部 27 份目录均已完成，每份 686 条，0 空译文、0 unfinished、0 obsolete；重新 lupdate 后 0 新增、0 废弃。自建校验及 Qt lcheck 通过，27 份 QM 编译成功，QTranslator 逐条核对 18,522 条运行时译文通过。
- 最终 macOS 应用构建成功（退出码 0），git diff --check 通过。新增维护说明记录更新、清理、校验流程及机器辅助翻译来源；其余语言尚未经过全面母语审校。本轮未操作真实磁盘，未提交或发布。

## Session: 原生标题文字拖动
- 用户指出文字区域仍无法拖动。补充 macOS GUI 初始化辅助函数，开启原生窗口背景拖动；QML 顶部 MouseArea 继续负责空白区。正文、红黄绿按钮、透明背景及原生窗口管理保持原有处理。
- 隔离测试通过：原生标题拖动开关已开启，标题 NSTextField 允许窗口移动、QNSView 正文不允许背景拖动；QML 空白区域收到按下事件，关闭保护、最小化/恢复、全屏/缩放能力标志通过。
- 验证工具限制：CUA 本轮对普通原生标题栏的对照拖动也无位置变化，重置工具后仍一样。未将实际拖动标记通过；已撤销中途试验的事件过滤器、事件监视器及不扩展客户区方案。工具关闭已退出的窗口时出现超时/procNotFound，进程检查确认测试窗口已退出。
- 最终 macOS 构建成功（退出码 0），git diff --check 通过；mac-dev.sh 会增量编译原生修改。测试进程已退出，未提交或发布。

## Session: 标题栏双击最大化
- 原生标题文字与空白区域统一处理双击，最大化后再次双击恢复原尺寸；保留透明标题栏、原生红黄绿按钮和既有拖动入口。其他平台自绘标题栏补充双击处理。
- 隔离 AppKit 事件测试通过：两处均可从 680×450 最大化至 2560×1410 并还原；正文双击不最大化，写入中关闭保护、最小化/恢复及原生窗口属性通过。测试应用已退出。
- 首次空白区 QML 双击测试失败，定位到系统拖动与双击处理冲突，统一为原生事件处理后通过。CUA 连接两次报 Sky Computer Use native pipe startup failed，因此本轮未验证真实鼠标双击，不将隔离事件测试表述为人工实测。
- 最终 macOS 构建成功（退出码 0），git diff --check 通过。包含原生代码修改，需退出旧进程并重新运行 mac-dev.sh 生效；未提交或发布。

## Session: 跨平台原生窗口
- 开始审计现有 macOS 原生按钮和非 macOS 自绘窗口；工作区已有大量用户改动，将在此基础上增量修改。
- 用户已选择 Linux 优先系统原生按钮和行为，透明/圆角/标题对齐跟随桌面主题。
- Qt v6.11.1 Windows ExpandedClientAreaHint 在平台插件内用 QPainter/Segoe 图标字体绘制按钮，并非 DWM 原生按钮；Windows 将使用 DWM 保留原生非客户区按钮的路径。
- 已实现 Windows DWM 辅助类和构建注册；main.qml 统一桌面原生装饰，移除桌面 Windows 的人工阴影与透明外边距。macOS 构建验证已启动。
- macOS 完整构建成功（退出码 0），差异空白检查通过。
- 隔离 macOS 预览首次编译误加 -fobjc-arc，与现有 winId → NSView 转换不兼容；移除该临时编译参数，与实际 CMake 构建保持一致，产品源码无此问题。
- macOS 隔离 AppKit 回归通过：标题与空白处双击最大化/还原、正文排除、原生按钮/透明属性、最小化恢复和关闭保护。预览自动退出。
- 新增独立 Windows DWM 回归探针（不链接刷写后端）及窗口平台支持/验收文档；Windows 环境不在本机，探针暂未执行。
- Windows/Linux QML 分支隔离预览首次缺少 overlayRoot 模拟对象导致加载失败，已补齐预览对象；此问题仅在临时裁剪的测试界面中出现。
- Windows/Linux 布局分支通过：桌面窗口均为非 frameless、无重复自绘按钮和人工阴影间距；Windows 标题左右对称避让原生按钮且居中，Linux 不附加应用标题行，QML 不拦截系统标题栏鼠标。
- 最终检查完成：macOS 编译成功，AppKit 原生事件回归通过，git diff --check 通过。Windows 的 DWM 源码与独立探针尚未在 Windows 编译/执行，Linux 原生装饰未实机测试；未将这些列为已通过。

## Session: Linux 优先 macOS 风格
- 用户改变 Linux 优先级，希望外观与 macOS 一致；改用统一自绘标题栏并明确按钮不再是桌面原生控件。
- Windows 仍保留 DWM 原生框架与系统阴影，本次无需修改其实现；显示效果仍需 Windows 实机验收。
- Linux 预览已目视确认左侧红黄绿按钮、居中标题和透明圆角。首轮合成双击没有触发，正在区分预览事件序列与产品逻辑；测试事件补齐第二次按下。
- 合成事件补齐第二次按下后，Linux 标题双击最大化/还原、点击抖动不拖动、真实位移请求拖动、四边/角落缩放入口、红黄绿操作与关闭保护全部通过；系统拖动/缩放调用在预览中仅计数，不冒充 Linux 合成器验证。
- 普通/弹窗截图已检查，圆角外区域 alpha=0，阴影 alpha 保留，弹窗遮罩没有覆盖阴影边距。测试退出被主动开启的写入保护拦截，已在临时测试结束前解除保护并清理测试进程。
- 用户进一步将 Linux 按钮指定为 Ubuntu 风格：从左侧红黄绿改为右侧 Yaru 风格按钮，其余透明圆角和标题交互保持。
- Linux 已改为右侧 Ubuntu/Yaru 风格按钮，中性圆形背景与深色图标，支持普通/悬浮/按下/失焦状态；最大化时显示还原图标。
- Linux 前一轮交互、Windows 布局及 macOS 原生回归均通过；当前继续验证 Ubuntu 按钮组的排列、避让和状态图标。
- Ubuntu 最终预览检查通过：普通态与还原态图标、按钮顺序/尺寸、标题居中与对称避让；失焦态和模拟激活态截图已核对。透明外角与弹窗遮罩保持圆角，轻阴影仍存在。
- 完整 macOS 构建退出码 0；Linux 自绘界面合成鼠标回归、Windows 原生布局分支、macOS AppKit 原生按钮/透明/双击/关闭保护回归全部通过。Linux 拖动/缩放的真实合成器行为与 Windows DWM 显示仍未实机测试。
- Windows DWM 源码没有变动；阴影仍由系统框架提供。本轮所有隔离预览已正常退出，git diff --check 通过。

## Session: Windows 11 按钮缺失
- 用户实机反馈 Windows 11 右上角三个按钮不可见。工作区干净，基线为 cc5583dd。
- 现有方案只保留 DWM 命中与窗口样式，并未为 Qt Quick 客户区覆盖后的标题按钮提供绘制层。之前的探针仅检查命中和动作，不能证明按钮可见；本轮修正验证范围。
- 修复 Windows clear color 为透明，新增共享 WindowFrameBackground 对原生按钮实测范围留空；BaseDialog 遮罩使用同一范围，标题颜色独立传给 DWM。
- Windows 辅助类按渲染后端、alpha buffer、DWM 可用性和有效按钮范围决定扩展；不支持时保留完整原生标题栏。新增激活/场景图初始化后的重算，保持非 layered 原生框架。
- Windows 独立探针新增实际桌面截图 glyph 对比、Quick alpha 检查、弹窗/最大化覆盖及软件回退测试；没有 Windows 环境，未编译或执行该探针。
- macOS 完整构建通过。使用当前 main.qml 前缀和真实 BaseDialog 做隔离 QML 像素检查：Windows 普通/弹窗按钮预留区 alpha=0，正文 alpha=255；Linux 普通/弹窗外角 alpha=0 且阴影存在；macOS 页面仍不透明。三种预览均正常退出。
- 临时测试 mock 首次在函数后写分号导致 QML 语法错误，修正 mock 后通过；字体相对路径缺失后补齐测试字体链接。产品构建无新增错误。
- git diff --check 通过。未将本机 QML 模拟检查称为 Windows 原生可见性或 Linux 合成器验证。

## Session: Windows 11 按钮区域空白
- 基线 d1079880，工作区干净。用户截图显示透出区域为白块且三个按钮未绘制，证实上一轮 alpha 留空不能解决实际按钮显示。
- 正在核对 Qt 官方 ExpandedClientAreaHint 的独立按钮绘制窗口和原生标题栏备选；已询问用户是否接受 Qt Windows 风格按钮，以明确原生性与融合外观的取舍。
- 用户选择 Qt 官方方案，保留融合外观与窗口操作，接受按钮由 Qt 按 Windows 风格绘制。
- Windows 切换 ExpandedClientAreaHint / NoTitleBarBackgroundHint / CustomizeWindowHint，保留三个按钮 hints，去掉原生标题 hint 避免重复标题。删除 Windows DWM helper、透明 cutout 组件及构建引用。
- 新增共享 WindowTitleBar，用 Qt SafeArea 预留高度、标题左右对称避让，Windows 拖动超过阈值才开始，双击最大化/还原；macOS 继续由既有 AppKit helper 处理。Windows GUI 请求浅色应用方案，与固定浅色页面保持按钮对比度。
- Windows 专用探针改为直接验证 Qt 独立标题栏绘制层及桌面三个 glyph，使用 SendInput 实际点击按钮、双击标题、验证关闭 veto，并覆盖默认和软件后端；不再用 alpha 留空断言冒充按钮可见验证。此探针未在 Windows 编译/运行。
- macOS 完整构建成功；Windows 分支 QML flags、单标题行、背景不留空、标题居中、双击最大化/还原、正文排除、真实 BaseDialog 遮罩检查通过。普通/弹窗右上角背景与同一行左侧背景像素完全一致且 alpha=255。
- macOS 原生交通灯、透明标题栏、标题与空白区双击最大化/还原、正文排除回归通过。Linux 普通/弹窗外角透明且阴影存在，正文 alpha=255。所有隔离预览正常退出。
- 文档已改为准确描述 Qt 绘制按钮以及 Windows 11 Snap 悬浮菜单不保证的边界。git diff --check 通过，未提交。
