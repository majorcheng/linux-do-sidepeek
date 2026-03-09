# AGENTS.md - Linux.do SidePeek 代理协作指南

## 项目定位

这是一个零构建的 Chrome 扩展（Manifest V3），目标是在 `https://linux.do` 站内为帖子链接提供右侧抽屉预览。

- 运行方式：Chrome 直接加载未打包目录
- 技术栈：原生 JavaScript + 原生 CSS
- 核心入口：`manifest.json`、`src/content.js`、`src/content.css`
- 当前没有 `package.json`，也没有 Node、打包器、测试框架或 Lint 配置

## 目录结构

核心运行文件：

```text
linux-do-sidepeek/
├── manifest.json
├── src/
│   ├── content.js
│   └── content.css
└── AGENTS.md
```

仓库里还包含 `README.md`、`CHANGELOG.md`、`POST_OVERVIEW.md`、`assets/`、`doc/`、`.github/workflows/release.yml` 等辅助文档与发布文件；涉及用户可见行为、版本说明或发版流程时不要忽略它们。

## 代理工作前提

- 这是单脚本 content script 项目，不要假设存在模块系统、构建产物或别名路径
- 对小改动优先直接编辑 `src/content.js` 和 `src/content.css`
- 除非用户明确要求，不要主动引入 npm、TypeScript、ESBuild、Webpack、Prettier、ESLint 或测试框架
- 若要新增文件，必须确认 `manifest.json` 是否需要同步引用；当前仅注入 `src/content.js` 与 `src/content.css`

## 外部规则文件状态

本仓库当前未发现以下文件，因此没有额外的 Cursor / Copilot 规则需要继承：

- `.cursorrules`
- `.cursor/rules/`
- `.github/copilot-instructions.md`

如果后续新增这些文件，应先读取并将其视为高优先级约束。

## 构建 / 运行 / 检查命令

### 构建

当前没有构建命令。

```bash
# 无 build 步骤
# 直接通过 Chrome 加载仓库目录即可
```

### 安装扩展

1. 打开 `chrome://extensions/`
2. 开启“开发者模式”
3. 点击“加载已解压的扩展程序”
4. 选择仓库根目录
5. 修改代码后点击扩展卡片上的“重新加载”

### Lint / 格式检查

当前没有自动化 Lint 或格式化命令。

```bash
# 无 eslint / prettier / stylelint 命令
```

代码检查依赖：

- 人工代码审查
- Chrome DevTools Console 报错检查
- 在真实页面上的功能回归

### 测试

当前没有自动化测试命令。

```bash
# 无 npm test / pnpm test / vitest / jest
```

### 运行单个测试

当前不适用：仓库里没有任何测试框架或测试文件，因此不存在“运行单个测试”的命令。

```bash
# N/A - no automated single-test command exists
```

如果未来引入测试框架，必须把“全量测试命令”和“单测命令”补写到本文件。

## 手动测试清单

每次功能改动后，至少验证与改动相关的路径；改动较大时执行完整清单：

1. 重载扩展并打开 `https://linux.do/latest`
2. 点击主题列表标题，确认右侧抽屉能打开并加载内容
3. 验证右上角“新标签打开”跳转正常
4. 验证“上一帖 / 下一帖”在列表页可用
5. 验证设置面板可打开、关闭、保存、恢复默认
6. 验证“智能预览 / 整页模式”切换正常
7. 验证“完整主题 / 仅首帖 / 最新回复优先”相关渲染逻辑
8. 验证拖拽调节宽度、刷新后宽度仍保留
9. 验证抽屉内图片点击会全屏放大，点击遮罩层、关闭按钮或 `Escape` 可退出
10. 验证带普通外链的图片仍按原链接打开，不会被抽屉预览误拦截
11. 验证切换到另一主题时不会残留上一张图的预览遮罩
12. 验证 `Escape` 关闭设置层与抽屉的行为
13. 用 DevTools Network 验证重复点击、切换模式、快速切帖时不会异常放大请求频率，也不会对同一主题短时间重复发起可避免的请求
14. 验证窄屏（尤其 `<= 720px`）布局不破版
15. 打开 Chrome DevTools，确认 Console 无新增错误

## 架构摘要

- `manifest.json`：声明 MV3 扩展、匹配站点与 content script 注入配置
- `src/content.js`：全部逻辑集中在一个 IIFE 中，负责事件代理、抽屉 UI、请求、状态、路由监听与设置持久化
- `src/content.css`：全部样式集中管理，使用 `ld-` 前缀避免污染站点样式
- `.github/workflows/release.yml`：标签匹配 `v*` 时自动打包 `manifest.json` 与 `src/` 并创建 GitHub Release

当前代码显式采用“单状态对象 + 函数分组”的组织方式，而不是类或模块拆分。

## JavaScript 代码风格

### 模块与导入

- 不使用 `import` / `export`
- 使用 IIFE 包裹整个 content script，避免污染全局作用域
- 不要把现有文件改造成 ES module，除非用户明确要求并同步调整 Manifest

### 语法与格式

- 使用 2 空格缩进
- 使用双引号字符串
- 保留分号
- 多行对象、数组、条件表达式按现有风格换行，不做无意义格式化噪音
- 优先使用早返回（guard clauses）减少嵌套

### 变量与函数

- 常量使用 `UPPER_SNAKE_CASE`，如 `ROOT_ID`
- 普通变量、函数、状态字段使用 `camelCase`
- 选择器常量使用 `_SELECTOR` 后缀
- 优先使用函数声明 `function foo() {}`，不要把普通函数随意改成箭头函数
- 使用 `const`，仅在确实会重新赋值时使用 `let`
- 禁止使用 `var`

### 类型与数据约束

- 本项目是纯 JavaScript，不要凭空加入 TypeScript 类型系统
- 通过运行时守卫做类型收窄，如 `instanceof`、`typeof`、`Array.isArray`
- 访问不确定数据时使用可选链和默认值
- 解析 URL、DOM、存储数据时先验证，再使用

### 状态管理

- 共享状态统一放在 `state` 对象内
- 新状态优先并入 `state`，不要散落为多个全局变量
- UI 引用、当前主题、请求控制器、用户设置都应保持单一事实来源

### DOM 操作

- 优先使用 `document.createElement()`、`append()`、`replaceChildren()`
- 事件处理优先用事件委托，当前代码主要挂在 `document` 上
- 操作 DOM 前先判断目标是否为 `Element` / `HTMLElement`
- 避免随意使用 `innerHTML`
- 仅在内容来源可信时使用 `innerHTML`；当前 `post.cooked` 来自 Discourse 已处理 HTML，属于现有可信边界
- 静态 UI 模板允许使用模板字符串，但新增动态内容优先走 DOM API 和 `textContent`

### 异步与网络请求

- 使用 `fetch` + `async/await`
- 请求应携带 `credentials: "include"`
- 可取消的异步流程必须继续使用 `AbortController`
- 被中断的请求视为预期行为，应静默退出，不要弹错或污染 UI
- 当 JSON 预览失败时，保持当前“降级为 iframe 预览”的容错策略

### 错误处理

- 对 URL 解析、网络请求、存储读取等易失败路径使用 `try/catch`
- 对用户可恢复的失败优先降级，不要让整个抽屉失效
- `abort`、无效链接、缺失节点等预期失败应直接返回
- 只有真正异常且需要用户感知时，才渲染错误提示

### 命名与语义

- 名称应直接体现用途：`openDrawer`、`loadTopic`、`applyDrawerWidth`
- 处理器命名统一用 `handleXxx`
- 构建 DOM 的函数统一用 `buildXxx`
- 渲染函数统一用 `renderXxx`
- 布尔值优先使用可读语义，如 `isResizing`、`hasShownPreviewNotice`

### 注释

- 先写可自解释代码，再考虑注释
- 非显而易见逻辑可以补充简短中文注释
- 不要写重复代码表意的废话注释

## CSS 代码风格

- 所有类名使用 `ld-` 前缀，避免与站点样式冲突
- 命名整体接近 BEM，但以当前项目现有风格为准
- 尽量把样式限定在 `#ld-drawer-root` 作用域下
- 优先复用站点 CSS 变量，如 `--primary`、`--secondary`、`--primary-low`
- 响应式断点以当前代码为准：重点关注 `1120px` 和 `720px`
- 宽度、间距、弹层位置优先沿用 `clamp()`、CSS 变量和现有布局模式

## 安全与兼容性约束

- 不要写入任何敏感信息
- 外链保留 `rel="noopener noreferrer"`
- 保持对 `https://linux.do/*` 的站内行为兼容，不要拦截无关链接
- Chrome 扩展改动要额外考虑“插件攻击面”：不要轻易扩大 `host_permissions`、`matches`、跨站请求范围、可执行注入点或数据读取范围
- 改动链接识别逻辑时，必须同时考虑列表页、搜索结果、用户流等入口
- 改动渲染逻辑时，必须考虑移动端与 Discourse 主题变量兼容性

## Review 重点

- 做代码评审时，除了功能对错，还要检查是否无意扩大了扩展攻击面，例如新增过宽站点权限、跨站 `fetch`、不必要的 `innerHTML`、可被帖子内容诱导触发的自动行为或对用户数据的额外读取。
- 任何会发请求的改动，都要 review 请求频率与去重策略：重复点击、模式切换、快捷键切帖、路由变化、失败重试等路径，不能把同一主题请求放大成高频或成倍重放。
- 涉及浏览计数、topic JSON、iframe 回退或预取逻辑时，优先复用现有 `AbortController`、状态锁和 tracking key；如果引入新请求，必须说明触发条件、上限和为什么不能复用现有请求。

## 提交改动时的建议流程

1. 先阅读 `manifest.json`、`src/content.js`、`src/content.css`
2. 尽量做最小必要改动，保持现有架构
3. 重载扩展并执行相关手动验证
4. 检查 Console、交互路径和响应式表现
5. 若修改了用户可感知行为，同步更新 `README.md`、`CHANGELOG.md`，必要时补充 `POST_OVERVIEW.md`
6. 若修改了行为约定，同步更新本文件；准备发版时，也要在 GitHub Release / Release Notes 中记录主要变化与致谢
