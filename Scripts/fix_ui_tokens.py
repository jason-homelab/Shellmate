#!/usr/bin/env python3
"""批量替换 SwiftUI 硬编码 UI 值为 DesignTokens 令牌"""

import re
import os
import sys

BASE = "/Users/jason/shellmate-app/ShellMate/ShellMate"

# 跳过的文件（终端渲染/纯逻辑文件）
SKIP_FILES = {
    'DesignTokens.swift', 'Color+Hex.swift', 'Collection+SafeSubscript.swift',
    'TerminalController.swift', 'TerminalController+SessionLog.swift',
    'TerminalTextView.swift', 'TerminalViewModel.swift',
    'LocalTerminalController.swift', 'LocalTerminalView.swift',
    'AIPanelViewModel.swift', 'SFTPPanelViewModel.swift',
    'SidebarViewModel.swift', 'WelcomeViewModel.swift',
    'HotkeyWindowManager.swift', 'ScriptModels.swift', 'ScriptStore.swift',
    'AppDelegate.swift', 'ShellMateApp.swift', 'WindowAppKitHelpers.swift',
    'AppConstants.swift', 'AppLogger.swift', 'AppVariant.swift',
    'ContentViewLifecycleModifier.swift', 'ContentViewActions.swift',
    'ButtonStyles.swift',  # 保留按钮样式文件原有逻辑
}


def replace_fonts(content: str) -> str:
    rules = [
        # 等宽代码字体（优先匹配，避免被普通规则覆盖）
        (r'\.font\(\.system\(size:\s*14,\s*(?:weight:\s*\.\w+,\s*)?design:\s*\.monospaced\)\)',
         '.font(DesignTokens.Typography.codeLarge)'),
        (r'\.font\(\.system\(size:\s*13,\s*(?:weight:\s*\.\w+,\s*)?design:\s*\.monospaced\)\)',
         '.font(DesignTokens.Typography.codeMedium)'),
        (r'\.font\(\.system\(size:\s*12,\s*(?:weight:\s*\.\w+,\s*)?design:\s*\.monospaced\)\)',
         '.font(DesignTokens.Typography.codeSmall)'),
        (r'\.font\(\.system\(size:\s*11,\s*(?:weight:\s*\.\w+,\s*)?design:\s*\.monospaced\)\)',
         '.font(DesignTokens.Typography.codeTiny)'),
        (r'\.font\(\.system\(size:\s*10,\s*(?:weight:\s*\.\w+,\s*)?design:\s*\.monospaced\)\)',
         '.font(DesignTokens.Typography.codeTiny)'),
        (r'\.font\(\.system\(size:\s*9,\s*(?:weight:\s*\.\w+,\s*)?design:\s*\.monospaced\)\)',
         '.font(DesignTokens.Typography.codeTiny)'),

        # Hero/Display 超大级
        (r'\.font\(\.system\(size:\s*56(?:,\s*weight:\s*\.\w+)?(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.heroHuge)'),
        (r'\.font\(\.system\(size:\s*52(?:,\s*weight:\s*\.\w+)?(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.heroXLarge)'),
        (r'\.font\(\.system\(size:\s*48(?:,\s*weight:\s*\.\w+)?(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.heroLarge)'),
        (r'\.font\(\.system\(size:\s*40(?:,\s*weight:\s*\.\w+)?(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.heroMedium)'),
        (r'\.font\(\.system\(size:\s*36(?:,\s*weight:\s*\.\w+)?(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.heroSmall)'),
        (r'\.font\(\.system\(size:\s*32(?:,\s*weight:\s*\.\w+)?(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.displayXLarge)'),
        (r'\.font\(\.system\(size:\s*28,\s*weight:\s*\.light(?:,\s*design:\s*\.rounded)?\)\)',
         '.font(DesignTokens.Typography.displayLarge)'),
        (r'\.font\(\.system\(size:\s*28(?:,\s*weight:\s*\.\w+)?(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.displayLarge)'),
        (r'\.font\(\.system\(size:\s*26(?:,\s*weight:\s*\.\w+)?(?:,\s*design:\s*\.rounded)?\)\)',
         '.font(DesignTokens.Typography.displayMedium)'),
        (r'\.font\(\.system\(size:\s*24(?:,\s*weight:\s*\.\w+)?(?:,\s*design:\s*\.rounded)?\)\)',
         '.font(DesignTokens.Typography.displaySmall)'),
        (r'\.font\(\.system\(size:\s*22(?:,\s*weight:\s*\.\w+)?(?:,\s*design:\s*\.rounded)?\)\)',
         '.font(DesignTokens.Typography.displaySmall)'),
        (r'\.font\(\.system\(size:\s*18(?:,\s*weight:\s*\.\w+)?(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.displayXSmall)'),

        # 标题级（semibold）
        (r'\.font\(\.system\(size:\s*20,\s*weight:\s*\.semibold(?:,\s*design:\s*\.rounded)?\)\)',
         '.font(DesignTokens.Typography.titleLarge)'),
        (r'\.font\(\.system\(size:\s*16,\s*weight:\s*\.semibold(?:,\s*design:\s*\.rounded)?\)\)',
         '.font(DesignTokens.Typography.titleMedium)'),
        (r'\.font\(\.system\(size:\s*15,\s*weight:\s*\.semibold(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.labelLargeAlt)'),
        (r'\.font\(\.system\(size:\s*15,\s*weight:\s*\.medium(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.labelLargeMid)'),
        (r'\.font\(\.system\(size:\s*14,\s*weight:\s*\.semibold(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.bodyLargeStrong)'),
        (r'\.font\(\.system\(size:\s*14,\s*weight:\s*\.medium(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.bodyLargeMedium)'),
        (r'\.font\(\.system\(size:\s*13,\s*weight:\s*\.semibold(?:,\s*design:\s*\.rounded)?\)\)',
         '.font(DesignTokens.Typography.titleSmall)'),

        # 标签级（medium）
        (r'\.font\(\.system\(size:\s*16,\s*weight:\s*\.medium(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.labelXLarge)'),
        (r'\.font\(\.system\(size:\s*13,\s*weight:\s*\.medium(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.labelLarge)'),
        (r'\.font\(\.system\(size:\s*12,\s*weight:\s*\.semibold(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.bodySmallStrong)'),
        (r'\.font\(\.system\(size:\s*12,\s*weight:\s*\.medium(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.labelMedium)'),
        (r'\.font\(\.system\(size:\s*11,\s*weight:\s*\.medium(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.labelSmall)'),
        (r'\.font\(\.system\(size:\s*11,\s*weight:\s*\.semibold(?:,\s*design:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.labelSmall)'),

        # 正文级（regular 或无 weight）— 排除 monospaced
        (r'\.font\(\.system\(size:\s*16\)\)',
         '.font(DesignTokens.Typography.titleMedium)'),
        (r'\.font\(\.system\(size:\s*20\)\)',
         '.font(DesignTokens.Typography.titleLarge)'),
        (r'\.font\(\.system\(size:\s*14,\s*weight:\s*\.regular\)\)',
         '.font(DesignTokens.Typography.bodyLarge)'),
        (r'\.font\(\.system\(size:\s*14\)\)',
         '.font(DesignTokens.Typography.bodyLarge)'),
        (r'\.font\(\.system\(size:\s*13,\s*weight:\s*\.regular\)\)',
         '.font(DesignTokens.Typography.bodyMedium)'),
        (r'\.font\(\.system\(size:\s*13\)\)',
         '.font(DesignTokens.Typography.bodyMedium)'),
        (r'\.font\(\.system\(size:\s*12,\s*weight:\s*\.regular\)\)',
         '.font(DesignTokens.Typography.bodySmall)'),
        (r'\.font\(\.system\(size:\s*12\)\)',
         '.font(DesignTokens.Typography.bodySmall)'),

        # 说明文字级
        (r'\.font\(\.system\(size:\s*11,\s*weight:\s*\.regular\)\)',
         '.font(DesignTokens.Typography.captionLarge)'),
        (r'\.font\(\.system\(size:\s*11\)\)',
         '.font(DesignTokens.Typography.captionLarge)'),
        (r'\.font\(\.system\(size:\s*10(?:,\s*weight:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.captionMedium)'),
        (r'\.font\(\.system\(size:\s*9(?:\.\d+)?(?:,\s*weight:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.captionSmall)'),
        (r'\.font\(\.system\(size:\s*8(?:,\s*weight:\s*\.\w+)?\)\)',
         '.font(DesignTokens.Typography.captionSmall)'),
    ]
    for pattern, replacement in rules:
        content = re.sub(pattern, replacement, content)
    return content


def replace_spacing(content: str) -> str:
    spacing_map = [
        ('64', 'DesignTokens.Spacing.massive'),
        ('48', 'DesignTokens.Spacing.giant'),
        ('40', 'DesignTokens.Spacing.huge'),
        ('32', 'DesignTokens.Spacing.xxxl'),
        ('24', 'DesignTokens.Spacing.xxl'),
        ('20', 'DesignTokens.Spacing.xl'),
        ('16', 'DesignTokens.Spacing.lg'),
        ('12', 'DesignTokens.Spacing.md'),
        ('8',  'DesignTokens.Spacing.sm'),
        ('6',  'DesignTokens.Spacing.xs'),
        ('5',  'DesignTokens.Spacing.micro'),
        ('4',  'DesignTokens.Spacing.xxs'),
        ('3',  'DesignTokens.Spacing.nano'),
        ('2',  'DesignTokens.Spacing.xxxs'),
        ('1',  'DesignTokens.Spacing.px'),
    ]
    edges = ['.horizontal', '.vertical', '.leading', '.trailing', '.top', '.bottom']

    for value, token in spacing_map:
        # .padding(X)
        content = re.sub(r'\.padding\(' + value + r'\)', f'.padding({token})', content)
        # .padding(.edge, X)
        for edge in edges:
            content = re.sub(
                r'\.padding\(' + re.escape(edge) + r',\s*' + value + r'\)',
                f'.padding({edge}, {token})',
                content
            )
        # spacing: X  (HStack/VStack 参数，必须紧跟逗号或闭括号)
        content = re.sub(
            r'(spacing:\s*)' + value + r'(?=\s*[,)\n])',
            r'\g<1>' + token, content
        )
    return content


def replace_corner_radius(content: str) -> str:
    radius_map = [
        ('24', 'DesignTokens.Sizes.cornerRadiusPanel'),
        ('16', 'DesignTokens.Sizes.cornerRadiusLarge'),
        ('12', 'DesignTokens.Sizes.cornerRadiusMedium'),
        ('8',  'DesignTokens.Sizes.cornerRadiusSmall'),
        ('6',  'DesignTokens.Sizes.cornerRadiusXSmall'),
        ('4',  'DesignTokens.Sizes.cornerRadiusXXSmall'),
        ('3',  'DesignTokens.Sizes.cornerRadiusMicro'),
        ('2',  'DesignTokens.Sizes.cornerRadiusTiny'),
    ]
    for value, token in radius_map:
        # .cornerRadius(X)
        content = re.sub(r'\.cornerRadius\(' + value + r'\)', f'.cornerRadius({token})', content)
        # RoundedRectangle(cornerRadius: X, ...) 或 RoundedRectangle(cornerRadius: X)
        content = re.sub(
            r'(RoundedRectangle\(cornerRadius:\s*)' + value + r'(?=[,\)])',
            r'\g<1>' + token, content
        )
    return content


def replace_colors(content: str) -> str:
    """只替换明确语义化的颜色"""
    # .foregroundColor(.secondary) / .foregroundStyle(.secondary)
    content = re.sub(
        r'\.foregroundColor\(\.secondary\)',
        '.foregroundColor(DesignTokens.Colors.textSecondary)',
        content
    )
    content = re.sub(
        r'\.foregroundStyle\(\.secondary\)',
        '.foregroundStyle(DesignTokens.Colors.textSecondary)',
        content
    )
    # .foregroundColor(.gray)
    content = re.sub(
        r'\.foregroundColor\(\.gray\)',
        '.foregroundColor(DesignTokens.Colors.textTertiary)',
        content
    )
    return content


def process_file(filepath: str) -> tuple[bool, int]:
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            original = f.read()
    except Exception as e:
        print(f"  ERROR reading {filepath}: {e}")
        return False, 0

    content = original
    content = replace_fonts(content)
    content = replace_spacing(content)
    content = replace_corner_radius(content)
    content = replace_colors(content)

    if content != original:
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            # 统计替换数量
            changes = sum(
                1 for a, b in zip(original.splitlines(), content.splitlines()) if a != b
            )
            return True, changes
        except Exception as e:
            print(f"  ERROR writing {filepath}: {e}")
            return False, 0
    return False, 0


def main():
    changed = []
    total_changes = 0

    for root, dirs, files in os.walk(BASE):
        # 跳过 .build 等隐藏目录
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for filename in sorted(files):
            if not filename.endswith('.swift'):
                continue
            if filename in SKIP_FILES:
                continue
            filepath = os.path.join(root, filename)
            modified, count = process_file(filepath)
            if modified:
                rel = filepath.replace(BASE + '/', '')
                changed.append((rel, count))
                total_changes += count

    print(f"\n✅ 共修改 {len(changed)} 个文件，约 {total_changes} 行变动：\n")
    for rel, count in sorted(changed):
        print(f"  {count:3d} 行  {rel}")

    print(f"\n总计: {total_changes} 处替换")


if __name__ == '__main__':
    main()
