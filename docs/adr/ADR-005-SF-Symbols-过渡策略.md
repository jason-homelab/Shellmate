# ADR-005：SF Symbols 迁移与 Unicode 共存过渡策略

**状态**：已采纳
**日期**：2026-06-07

## 背景

工具栏当前使用 Unicode 图标（⏻ ✦ </> ⇅ ⊡）。需迁移至 SF Symbols 以解决：
- 字宽不一致（CJK 环境）
- 无 a11y label
- 视觉重量不可控

但全量替换跨 W3 一周，需要过渡策略。

## 决策

1. 新建 `AppIcon` enum，**所有图标必须经此枚举访问**
2. W3 内一次性切换，不支持长期共存
3. SwiftLint 自定义规则禁止业务侧出现 `Image(systemName:)` 字面量
4. macOS 13 兼容：选符限制在 SF Symbols 4.0 内
5. AppIcon 自带 `a11yLabel` 映射，与 AccessibilityCatalog 联动

## 理由

- 共存期会形成两套图标语言，反而损害一致性
- 集中切换 + Lint 防御一次解决

## 后果

- ✅ a11y 标签随 AppIcon 自动绑定
- ✅ 未来主题切换、权重调整集中处理
- ⚠️ W3 当周禁止新加 UI 图标
