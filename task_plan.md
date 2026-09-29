# Task Plan: 修复主界面截图中的八项 UI 问题

## Goal
解决截图中发现的八项界面问题，同时保留现有 QML live、manifest 缓存、设备选择和 ZimaOS 定制功能。

## Current Phase
Phase 13：macOS 个别机器无法打开诊断与修复

## Phases

### Phase 1: 基线与布局检查
- [x] 记录当前窗口尺寸、DPI 缩放和 QML live 启动方式
- [x] 检查布局边界并保留现有功能改动
- **Status:** complete

### Phase 2: 标题与底部操作区
- [x] 将右侧标题固定在内容框上方，并统一顶部间距
- [x] 将底部按钮固定在内容框下方
- [x] 保证中间内容区域使用 `Layout.fillHeight` 自适应
- [x] 验证不同窗口高度下标题、内容和按钮不重叠
- **Status:** complete

### Phase 3: 内容框视觉样式
- [x] 恢复右侧内容框白色背景、圆角和边框
- [x] 调整内容框内边距，避免标题贴边
- [x] 处理单条设备数据时的空白区域和内容比例
- **Status:** complete

### Phase 4: 左侧导航排版
- [x] 将导航项高度固定为 `40px`
- [x] 缩小“设置步骤”标题字号，使其与页面标题协调
- [x] 提高未激活导航项的文字对比度
- [x] 校正导航项之间的间距和底部空间
- **Status:** complete

### Phase 5: 设备卡片与按钮状态
- [x] 明确设备卡片默认、悬浮、选中和禁用状态
- [x] 为选中设备提供清晰但不过重的边框/背景
- [x] 修正“下一步”禁用状态的颜色和可理解性
- [x] 验证选择设备后按钮及时启用
- **Status:** complete

### Phase 6: 设置按钮与窗口边框
- [x] 去除设置图标不必要的外部边框和大面积背景
- [x] 保留可访问性、键盘焦点和点击反馈
- [x] 评估并实现 macOS 无原生 Title Bar 的自定义窗口标题栏
- [x] 保证窗口拖拽、关闭、最小化和最大化行为正常
- **Status:** complete

### Phase 7: 多尺寸验证
- [x] 使用 QML live 启动验证修改即时生效
- [x] 验证 Retina/DPI 缩放下的实际视觉尺寸
- [x] 验证中文和英文文本不会溢出或被截断
- [x] 检查设备列表为空、单条、多条和加载中的状态
- **Status:** complete

### Phase 8: 构建与回归
- [x] 执行 `ninja -C build zimaos-usb-creator`
- [x] 执行 `./mac-dev.sh --qml-live`
- [x] 检查 QML 警告、启动页面和导航切换
- [x] 汇总变更、已知限制和截图对比结果
- **Status:** complete

### Phase 9: 补充布局约束
- [x] 左侧导航项右侧保留 `8px` 间距
- [x] 导航边框颜色与右侧内容框边框颜色统一
- [x] 右侧底部按钮底边与左侧导航底边对齐
- [x] 缩小设置按钮并保持左下角定位
- [x] 在普通窗口和 Retina 缩放下验证对齐关系
- **Status:** complete

### Phase 10: 第二轮截图问题修复
- [x] 将应用最外层改为圆角透明窗口，消除直角外框
- [x] 弱化或移除应用外框边线，保留必要的窗口阴影
- [x] 缩小 Title Bar 高度，收紧标题与交通灯间距
- [x] 增加 Title Bar 与主界面之间的分隔层次
- [x] 调整左侧导航的垂直分布，减少底部无效空白
- [x] 提高未激活导航项的文字对比度，避免与激活项差距过大
- [x] 限制右侧内容框最大高度或优化单条设备记录的垂直布局
- [x] 降低设备选中边框的蓝色视觉重量
- [x] 减少“下一步”按钮与内容框之间的垂直间距
- [x] 将设备图标、名称和描述在卡片内垂直居中
- [x] 统一左右主区域的圆角半径与边框颜色
- [x] 优化窗口放大后的内容约束，避免空白区域无限扩大
- **Status:** complete

### Phase 11: 优先级验收
- [x] 优先验收圆角透明窗口
- [x] 优先验收 Title Bar 高度和分隔线
- [x] 优先验收右侧内容最大宽高与垂直布局
- [x] 优先验收左侧导航颜色和底部空间
- [x] 优先验收设备卡片选中态和内部垂直居中
- **Status:** complete

### Phase 12: Style token 语义重构
- [ ] 建立规范的颜色、间距、几何、控件尺寸分类
- [ ] 迁移核心 QML 页面到规范 token
- [ ] 清理已无引用的旧 token 和重复别名
- [ ] 检查所有 QML 引用和格式
- [ ] 完成构建与 live 启动回归
- **Status:** in_progress

### Phase 13: macOS 个别机器无法打开诊断与修复
- [ ] 审计实际应用包的架构、最低系统版本、签名和公证状态
- [ ] 核对构建与 DMG 脚本中的签名顺序、entitlements 和产物选择
- [ ] 修复可确认的分发兼容性问题，并加入构建期失败检查
- [ ] 构建并验证应用包、归档或 DMG 的 Gatekeeper 接受状态
- [ ] 记录仍需从故障机器收集的诊断信息
- **Status:** in_progress（源码修复完成；需在干净构建目录执行最终发布构建）

### Phase 1: Preserve Current Work
- [x] Inspect current branch and upstream divergence
- [x] Commit current workspace changes
- [x] Create a local backup branch
- **Status:** complete

### Phase 2: Merge Upstream
- [x] Merge `upstream/main` into `main` with a merge commit
- [x] Resolve conflicts without reverting ZimaOS branding and local product changes
- **Status:** complete

### Phase 3: Verify
- [x] Inspect unresolved conflict markers and repository status
- [x] Configure and build the macOS target
- [x] Record test results
- **Status:** complete

### Phase 4: Handoff
- [x] Summarize merge result and remaining risks
- [x] Leave changes unpushed
- **Status:** complete

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Use `git merge --no-ff` rather than rebase | Preserves the fork's existing public history and makes the upstream sync explicit. |
| Do not push | Remote state changes require separate user authorization. |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| Standard merge produced broad branding/UI/translation conflicts | 1 | Abort and retry with `-X ours` so conflicting hunks retain fork behavior while clean upstream changes merge. |

## Task: 恢复内容存储库设置（2026-09-22）
- [x] 查找删除提交并确认当前接口
- [x] 恢复设置入口和存储库对话框，适配当前 QML
- [x] 构建并验证切换操作

## Task: 仓库设置样式调整
- [x] 修复开关右对齐，移除仓库 radio 默认背景
- [x] 文件框与浏览按钮组成等高圆角控件组，统一 URL 样式
- [x] 实际界面检查与构建验证

## Task: 写入进度圆角和 Windows 控件背景（2026-09-28）
- [x] 定位起始进度圆角和浅蓝状态背景的来源
- [x] 修复公共控件样式，保留键盘焦点反馈
- [x] 构建并验证起始/小进度/完成进度及按钮状态
- [x] 取消仓库默认来源的整行大高亮框，仅在圆形单选标记上显示键盘焦点

本次验证工具问题（已解决）：本地无 QtTest 模块，改用临时 QML 预览断言；预览绝对路径改为 file: 导入；原生 contentItem 无 QML engine，截图改抓 QML 容器。

## Task: 应用数据目录改为 IceWhale（2026-09-28）
- [x] 查明 Qt 组织名及目录、设置关联
- [x] 更新 GUI / CLI 组织名并保留旧缓存和设置兼容
- [x] 构建并验证新目录与兼容行为

## Task: 组织目录名称更正为 IceWhaleTech
- [x] 更新最终组织名并兼容 IceWhale 和 Raspberry Pi 两个旧目录
- [x] 构建并验证实际缓存读取路径

## Task: 组织域名更正为 zimaspace.com
- [x] 设置当前域名 zimaspace.com、组织名 IceWhaleTech，并统一字体缩放设置读取
- [x] 显式读取 macOS 旧域名设置进行兼容迁移
- [x] 构建并验证域名、设置保留和缓存路径

验证工具调整：本地 Qt 使用 include/libQt6Core.dylib 布局，独立探针最初误用 Framework 路径，已修正编译参数。

## Task: 美化写入前擦除确认弹窗
- [x] 调整警告、设备信息和操作区层次，保持倒计时前后布局稳定
- [x] 保留 2 秒确认延迟、取消与无障碍操作，补充中英文文案
- [x] 预览长设备名及倒计时/可确认状态，构建验证

本次预览问题（已解决）：默认 Dialog header 与自定义标题重复导致底部裁切，已设置 header: null；150% 字体下按钮文字省略，已使用实际文本预留宽度并缩放按钮尺寸。

## Task: 擦除弹窗图标与排版微调
- [x] 去除警告图标背景，改为图标与标题居中对齐、说明与标题左对齐
- [x] 目标存储设备改用现有 USB 图标
- [x] 预览并构建验证

## Task: 优化应用选项与内容仓库弹窗
- [x] 统一白色圆角面板、左对齐标题、分组内容与底部操作区
- [x] 优化设置行和仓库来源说明、内联文件/URL 输入及反馈
- [x] 验证普通/展开/长文本与缩放状态、保存取消行为和构建

## Task: 优化禁用警告确认弹窗
- [x] 统一圆角白色面板、无背景警告图标、分层说明与确认操作
- [x] 验证取消/确认、大字号与中英文预览，并完成构建

## Task: 弹窗操作按钮与底部导航等高
- [x] 使用相同 buttonHeightStandard（32px）替换弹窗的 40px 高度
- [x] 预览核对高度并构建

## Task: 优化通用错误弹窗
- [x] 统一圆角白色面板、错误图标和详情分区，沿用 32px 操作按钮
- [x] 验证权限错误、长文本和缩放布局、关闭交互及构建
