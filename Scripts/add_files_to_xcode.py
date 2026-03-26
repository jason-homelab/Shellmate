#!/usr/bin/env python3
"""
将缺失的 Swift 文件添加到 Xcode 项目
"""

import os
import re
import uuid

# 项目文件路径
PROJECT_FILE = "/Users/jason/shellmate-app/ShellMate/ShellMate.xcodeproj/project.pbxproj"

# 需要添加的文件（相对于 ShellMate/ShellMate 目录）
MISSING_FILES = [
    # Terminal 功能
    ("Features/Terminal/TerminalView.swift", "Terminal"),
    ("Features/Terminal/TerminalController.swift", "Terminal"),
    ("Features/Terminal/TerminalToolbarView.swift", "Terminal"),
    ("Features/Terminal/ShellMateTerminalView.swift", "Terminal"),

    # SSH 服务
    ("Core/Services/SSH/SSHConnection.swift", "SSH"),
    ("Core/Services/SSH/SSHSessionConfig.swift", "SSH"),
    ("Core/Services/SSH/SSHError.swift", "SSH"),
    ("Core/Services/SSH/SSHEventLoop.swift", "SSH"),
    ("Core/Services/SSH/SSHNetworkUtils.swift", "SSH"),
    ("Core/Services/SSH/SSHAuthService.swift", "SSH"),
    ("Core/Services/SSH/SSHChannelManager.swift", "SSH"),
    ("Core/Services/SSH/SSHProcessBridge.swift", "SSH"),
    ("Core/Services/SSH/SSHProxyJump.swift", "SSH"),
    ("Core/Services/SSH/LibSSH2Bridge.swift", "SSH"),
    ("Core/Services/SSH/KnownHostsManager.swift", "SSH"),

    # 共享组件
    ("Shared/Components/FormComponents.swift", "Components"),
    ("Shared/Components/HostKeyConfirmationView.swift", "Components"),
    ("Shared/Components/HostKeyChangedWarningView.swift", "Components"),
]

def generate_id():
    """生成 Xcode 项目文件 ID"""
    return uuid.uuid4().hex[:24].upper()

def read_project_file():
    with open(PROJECT_FILE, 'r') as f:
        return f.read()

def write_project_file(content):
    with open(PROJECT_FILE, 'w') as f:
        f.write(content)

def main():
    content = read_project_file()

    # 检查哪些文件需要添加
    files_to_add = []
    for file_path, group in MISSING_FILES:
        filename = os.path.basename(file_path)
        if filename not in content:
            files_to_add.append((file_path, filename, group))
            print(f"需要添加: {filename}")
        else:
            print(f"已存在: {filename}")

    if not files_to_add:
        print("\n所有文件都已添加到项目中")
        return

    print(f"\n共需添加 {len(files_to_add)} 个文件")

    # 为每个文件生成 ID
    file_entries = []
    build_entries = []

    for file_path, filename, group in files_to_add:
        file_ref_id = generate_id()
        build_file_id = generate_id()

        # PBXFileReference 条目
        file_ref = f'\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = "<group>"; }};'
        file_entries.append((file_ref_id, filename, file_ref))

        # PBXBuildFile 条目
        build_file = f'\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};'
        build_entries.append((build_file_id, filename, build_file, file_ref_id))

    # 插入 PBXFileReference 条目
    file_ref_marker = "/* End PBXFileReference section */"
    file_refs_text = "\n".join([entry[2] for entry in file_entries])
    content = content.replace(file_ref_marker, file_refs_text + "\n" + file_ref_marker)

    # 插入 PBXBuildFile 条目
    build_file_marker = "/* End PBXBuildFile section */"
    build_files_text = "\n".join([entry[2] for entry in build_entries])
    content = content.replace(build_file_marker, build_files_text + "\n" + build_file_marker)

    # 添加到 Sources 构建阶段
    # 找到 Sources 构建阶段的 files 数组
    sources_pattern = r'(/\* Sources \*/ = \{[^}]*files = \()([^)]*?)(\);)'

    def add_to_sources(match):
        prefix = match.group(1)
        existing = match.group(2)
        suffix = match.group(3)

        new_entries = ",\n".join([f"\t\t\t\t{entry[0]} /* {entry[1]} in Sources */" for entry in build_entries])
        if existing.strip():
            return prefix + existing.rstrip() + ",\n" + new_entries + "\n\t\t\t" + suffix
        else:
            return prefix + "\n" + new_entries + "\n\t\t\t" + suffix

    content = re.sub(sources_pattern, add_to_sources, content, flags=re.DOTALL)

    # 写回文件
    write_project_file(content)
    print(f"\n✅ 已添加 {len(files_to_add)} 个文件到项目")
    print("请在 Xcode 中重新打开项目并将文件拖到正确的分组中")

if __name__ == "__main__":
    main()
