# 阶段 Review 技能

执行 ShellMate 项目阶段性 Review，参考所有设计和技术文档，生成标准化审查报告。

## 参数说明

调用格式：`/phase-review [阶段编号]`
例如：`/phase-review M1` 或 `/phase-review 1`

如果未指定阶段编号，根据 `开发进度.md` 中的当前进度自动判断最近完成的里程碑阶段。

---

## 执行步骤

当此技能被调用时，请严格按以下步骤执行：

### 第一步：确定阶段编号

- 读取用户传入的参数作为阶段编号（M1/M2/M3/M4 或数字 1/2/3/4）
- 如果未传入参数，读取 `/Users/jason/shellmate-app/开发进度.md`，从文档状态判断当前正在进行或刚完成的里程碑阶段
- 统一使用数字表示（M1→1, M2→2, M3→3, M4→4）

### 第二步：获取当前时间

- 使用 Bash 执行 `date +%Y%m%d%H%M` 获取当前时间戳（格式：yyyymmddhhmm）

### 第三步：并行读取所有参考文档

同时读取以下文档：

**需求/设计层：**
- `/Users/jason/shellmate-app/ShellMate_MRD.md`
- `/Users/jason/shellmate-app/ShellMate_PRD.md`
- `/Users/jason/shellmate-app/原型.md`

**技术架构层：**
- `/Users/jason/shellmate-app/技术方案.md`
- `/Users/jason/shellmate-app/数据库设计文档.md`

**UI 设计规范层（全部读取）：**
- `/Users/jason/shellmate-app/shellmate-figma-spec/00-总纲与设计令牌.md`
- `/Users/jason/shellmate-app/shellmate-figma-spec/01-界面布局规范.md`
- `/Users/jason/shellmate-app/shellmate-figma-spec/02-SF_Symbols图标规范.md`
- `/Users/jason/shellmate-app/shellmate-figma-spec/03-动效与交互规范.md`
- `/Users/jason/shellmate-app/shellmate-figma-spec/04-可访问性与Handoff检查清单.md`
- `/Users/jason/shellmate-app/shellmate-figma-spec/05-弹窗D04D05规范.md`
- `/Users/jason/shellmate-app/shellmate-figma-spec/06-设置面板规范.md`
- `/Users/jason/shellmate-app/shellmate-figma-spec/07-终端覆层规范.md`
- `/Users/jason/shellmate-app/shellmate-figma-spec/08-缺失组件补充.md`

**进度追踪：**
- `/Users/jason/shellmate-app/开发进度.md`

**当前代码状态：**
- 执行 `git -C /Users/jason/shellmate-app log --oneline -20` 获取最近提交记录
- 执行 `git -C /Users/jason/shellmate-app status` 获取当前状态

### 第四步：逐项核查该阶段验收条件

根据 `开发进度.md` 中对应里程碑（M1/M2/M3/M4）的验收条件，逐条检查：
1. 代码层面是否有对应实现（结合 git log 与已知代码结构）
2. UI 实现是否符合 Figma 规范
3. 技术实现是否符合技术方案
4. 数据模型是否符合 PRD 和数据库设计
5. 功能是否覆盖 PRD 中的 P0 用例
6. 是否与 MRD 产品目标对齐

### 第五步：输出报告

将 Review 报告写入 `/Users/jason/shellmate-app/项目Review报告-M{阶段编号}-{yyyymmddhhmm}.md`

---

## 报告模板结构

报告必须包含以下章节（使用中文）：

```markdown
# ShellMate 项目 Review 报告 — M{N} 阶段
> **阶段：** M{N} — {阶段名称}
> **生成时间：** {yyyy-MM-dd HH:mm}
> **审查范围：** {本阶段周次范围，如 W1–W5}
> **总体评级：** {通过 ✅ / 部分通过 ⚠️ / 未通过 ❌}

---

## 1. 执行摘要

{100-200字的总体评估，包括本阶段核心成果、主要风险点和总体完成度百分比}

---

## 2. 验收条件核查

| # | 验收条件 | 状态 | 评估说明 |
|---|---------|------|---------|
| 1 | {条件描述} | ✅/⚠️/❌ | {具体说明} |
...

**本阶段验收通过率：** X/Y（XX%）

---

## 3. PRD P0 用例对齐检查

{对照 PRD 中属于本阶段的 P0 级验收用例逐条核查}

| 用例 | 描述 | 状态 | 备注 |
|------|------|------|------|
...

---

## 4. UI/Figma 规范符合度

### 4.1 设计令牌使用
{检查颜色、字体、间距等设计令牌使用是否符合 00-总纲}

### 4.2 组件实现符合度
{对照 Figma 规范检查各组件实现}

### 4.3 动效与交互
{对照 03-动效规范检查}

### 4.4 可访问性
{VoiceOver 标签、对比度等}

**UI 规范符合度：** {优/良/中/差}

---

## 5. 技术架构符合度

### 5.1 架构层次遵循
{检查 4 层架构是否正确}

### 5.2 Swift Concurrency 使用
{async/await 使用、GCD 残留检查}

### 5.3 安全规范
{凭据存储、日志安全等}

### 5.4 数据模型符合度
{Core Data 实体与设计文档的对比}

**技术规范符合度：** {优/良/中/差}

---

## 6. 风险与问题清单

| 优先级 | 问题描述 | 影响范围 | 建议措施 |
|-------|---------|---------|---------|
| P0 | | | |
| P1 | | | |
...

---

## 7. 下一阶段建议

{针对下一个里程碑阶段（M{N+1}），基于本次 Review 发现的问题，提出具体的改进建议和注意事项}

---

## 8. 附录：核查依据

- MRD 版本：{版本}
- PRD 版本：{版本}
- 技术方案版本：{版本}
- Figma 规范版本：{版本}
- 审查 Git 范围：最近 20 次提交
```

---

## 注意事项

1. 所有输出内容使用中文
2. 对于无法通过文档直接验证的条目，标注"需人工验证"而非猜测
3. 如果某个阶段的文档不存在，记录"文档缺失"并继续
4. 报告必须客观，不要夸大完成度，也不要过度悲观
5. 报告文件名精确格式：`项目Review报告-M{N}-{yyyymmddhhmm}.md`（N 为数字，时间为实际执行时间）
