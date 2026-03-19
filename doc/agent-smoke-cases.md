# Agent Smoke 用例库

这份文档记录当前可复用的 `agent-browser` Chrome smoke 用例。

规则：

1. 每个用例都有固定 ID
2. 每个用例只写稳定断言
3. 每次修线上回归，补一个对应回归用例

## 1. 前置条件

### 浏览器

```bash
google-chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-codex
```

### 扩展

1. 打开 `chrome://extensions/`
2. 开启 `Developer mode`
3. `Load unpacked`
4. 选择仓库根目录
5. 代码改动后点击 `Update`

### agent 连接

```bash
agent-browser --cdp 9222 get url
agent-browser --cdp 9222 snapshot -i
```

### 批量执行

```bash
bash scripts/agent-smoke.sh --cdp-port 9222
```

指定用例：

```bash
bash scripts/agent-smoke.sh --cdp-port 9222 --cases AGENT-CHROME-001,AGENT-CHROME-006
```

## 2. 用例

### AGENT-CHROME-001：列表点击打开抽屉

范围：
列表页主题标题点击拦截

步骤：

1. 打开 `https://linux.do/latest`
2. 点击任一主题主标题

断言：

1. `location.href` 仍然停留在列表页
2. `#ld-drawer-root` 存在
3. 抽屉标题已更新成点击的话题标题

### AGENT-CHROME-002：抽屉基础工具栏

范围：
抽屉基础控件渲染

步骤：

1. 先执行 `AGENT-CHROME-001`

断言：

1. `上一帖` 按钮存在
2. `下一帖` 按钮存在
3. `选项` 按钮存在
4. `新标签打开` 链接存在

### AGENT-CHROME-003：设置面板打开和关闭

范围：
设置面板交互

步骤：

1. 先执行 `AGENT-CHROME-001`
2. 点击 `选项`
3. 再点击 `选项` 或设置面板关闭按钮

断言：

1. 打开后 `aria-expanded="true"`
2. 设置层不再带 `hidden`
3. 关闭后 `aria-expanded="false"`
4. 设置层恢复 `hidden`

### AGENT-CHROME-004：列表内上一帖 / 下一帖切换

范围：
列表内主题切换

步骤：

1. 先执行 `AGENT-CHROME-001`
2. 点击 `下一帖`

断言：

1. 抽屉标题切换成另一条话题
2. `location.href` 仍然停留在列表页

### AGENT-CHROME-005：浮层模式外部点击关闭

范围：
`#3` 抽屉模式 + `#4` 外部点击关闭

步骤：

1. 打开一个话题抽屉
2. 在 `选项` 中切到 `浮层模式`
3. 点击抽屉外的页头或列表空白区

断言：

1. `body` 不再带 `ld-drawer-page-open`
2. `body` 不再带 `ld-drawer-mode-overlay`
3. 页面 URL 不发生意外跳转

### AGENT-CHROME-006：浮层模式下点击另一个列表项应直接切换

范围：
`#4` 回归用例，2026-03-19 新增

步骤：

1. 打开一个话题抽屉
2. 在 `选项` 中切到 `浮层模式`
3. 抽屉保持打开时，直接点击另一个列表主题标题

断言：

1. 一次点击后抽屉标题直接切换成新话题
2. 不允许出现“第一次只关闭抽屉，第二次才打开”的行为
3. `location.href` 仍然停留在列表页

### AGENT-CHROME-007：Topic Owner 标记

范围：
楼主标记

状态：
当前不在默认批量脚本中

建议目标：
优先选楼主有多次回复的公告帖

步骤：

1. 打开目标话题
2. 读取抽屉中的作者行

断言：

1. 楼主回复存在 `Topic Owner`
2. 非楼主回复不带该标记

### AGENT-CHROME-008：新话题提示条点击回顶

范围：
`#4` 提示条固定与点击行为

状态：
批量脚本中为“存在则执行，否则 `SKIP`”

步骤：

1. 打开 `https://linux.do/latest`
2. 向下滚动
3. 等待“查看 x 个新的或更新的话题”提示条出现
4. 点击提示条

断言：

1. 提示条在中间栏顶部区域可见
2. 点击后 `scrollY` 回到顶部
3. `location.href` 保持在列表页

### AGENT-CHROME-009：新标签打开链接属性

范围：
抽屉跳转链接安全属性

步骤：

1. 打开任一话题抽屉
2. 读取 `新标签打开` 链接属性

断言：

1. `target="_blank"`
2. `rel="noopener noreferrer"`
3. `href` 指向当前抽屉对应的话题 URL

### AGENT-CHROME-010：最新回复刷新按钮

范围：
`#6` 最新回复刷新按钮

步骤：

1. 打开任一列表话题
2. 在 `选项` 中切到 `智能预览`、`完整主题`、`首帖 + 最新回复`
3. 确认工具栏出现 `刷新` 按钮
4. 点击 `刷新`

断言：

1. 点击前 `刷新` 按钮存在、可见、可点击
2. 点击后按钮立即进入禁用态，并显示 `刷新中...`
3. 刷新完成后按钮恢复为 `刷新`
4. 过程中 `location.href` 保持在列表页，抽屉不关闭

## 3. 记录格式

执行完用例后，建议按下面格式留证据：

```text
AGENT-CHROME-006 PASS
- title_before: 抽3个100元支付宝红包
- action: 点击列表中的 antigravity也要拉闸了？？
- title_after: antigravity也要拉闸了？？
- url: https://linux.do/latest
```

## 4. 不纳入 agent 用例库的项

以下内容继续保留人工判断：

1. Firefox 浏览器内完整功能回归
2. 窄屏 / 响应式观感
3. 纯视觉布局是否正常
4. 浏览计数变化
