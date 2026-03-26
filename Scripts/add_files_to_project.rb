#!/usr/bin/env ruby
# 将缺失的 Swift 文件添加到 Xcode 项目
# 使用正确的 pbxproj 格式

require 'securerandom'

PROJECT_FILE = '/Users/jason/shellmate-app/ShellMate/ShellMate.xcodeproj/project.pbxproj'

# 需要添加的文件（相对于 ShellMate/ShellMate 目录）
MISSING_FILES = [
  # Terminal 功能
  { path: 'Features/Terminal/TerminalView.swift', name: 'TerminalView.swift' },
  { path: 'Features/Terminal/TerminalController.swift', name: 'TerminalController.swift' },
  { path: 'Features/Terminal/TerminalToolbarView.swift', name: 'TerminalToolbarView.swift' },
  { path: 'Features/Terminal/ShellMateTerminalView.swift', name: 'ShellMateTerminalView.swift' },

  # SSH 服务
  { path: 'Core/Services/SSH/SSHConnection.swift', name: 'SSHConnection.swift' },
  { path: 'Core/Services/SSH/SSHSessionConfig.swift', name: 'SSHSessionConfig.swift' },
  { path: 'Core/Services/SSH/SSHError.swift', name: 'SSHError.swift' },
  { path: 'Core/Services/SSH/SSHEventLoop.swift', name: 'SSHEventLoop.swift' },
  { path: 'Core/Services/SSH/SSHNetworkUtils.swift', name: 'SSHNetworkUtils.swift' },
  { path: 'Core/Services/SSH/SSHAuthService.swift', name: 'SSHAuthService.swift' },
  { path: 'Core/Services/SSH/SSHChannelManager.swift', name: 'SSHChannelManager.swift' },
  { path: 'Core/Services/SSH/SSHProcessBridge.swift', name: 'SSHProcessBridge.swift' },
  { path: 'Core/Services/SSH/SSHProxyJump.swift', name: 'SSHProxyJump.swift' },
  { path: 'Core/Services/SSH/LibSSH2Bridge.swift', name: 'LibSSH2Bridge.swift' },
  { path: 'Core/Services/SSH/KnownHostsManager.swift', name: 'KnownHostsManager.swift' },

  # 共享组件
  { path: 'Shared/Components/FormComponents.swift', name: 'FormComponents.swift' },

  # HostKey 功能
  { path: 'Features/HostKey/HostKeyConfirmationView.swift', name: 'HostKeyConfirmationView.swift' },
  { path: 'Features/HostKey/HostKeyChangedWarningView.swift', name: 'HostKeyChangedWarningView.swift' },
]

def generate_id
  # 生成 24 字符的十六进制 ID
  SecureRandom.hex(12).upcase
end

def main
  content = File.read(PROJECT_FILE)

  # 检查哪些文件需要添加
  files_to_add = []
  MISSING_FILES.each do |file|
    unless content.include?(file[:name])
      files_to_add << file
      puts "需要添加: #{file[:name]}"
    else
      puts "已存在: #{file[:name]}"
    end
  end

  if files_to_add.empty?
    puts "\n所有文件都已添加到项目中"
    return
  end

  puts "\n共需添加 #{files_to_add.length} 个文件"

  # 为每个文件生成条目
  file_ref_entries = []
  build_file_entries = []
  sources_entries = []

  files_to_add.each do |file|
    file_ref_id = generate_id
    build_file_id = generate_id

    # PBXFileReference 条目
    file_ref_entries << "\t\t#{file_ref_id} /* #{file[:name]} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = #{file[:name]}; sourceTree = \"<group>\"; };"

    # PBXBuildFile 条目
    build_file_entries << "\t\t#{build_file_id} /* #{file[:name]} in Sources */ = {isa = PBXBuildFile; fileRef = #{file_ref_id} /* #{file[:name]} */; };"

    # Sources 条目
    sources_entries << "\t\t\t\t#{build_file_id} /* #{file[:name]} in Sources */,"
  end

  # 插入 PBXFileReference 条目
  marker = "/* End PBXFileReference section */"
  content = content.sub(marker, file_ref_entries.join("\n") + "\n" + marker)

  # 插入 PBXBuildFile 条目
  marker = "/* End PBXBuildFile section */"
  content = content.sub(marker, build_file_entries.join("\n") + "\n" + marker)

  # 添加到 Sources 构建阶段
  # 找到 Sources 阶段的 files 数组
  content = content.gsub(/(\* Sources \*\/ = \{[^}]*files = \()([^)]*?)(\);)/m) do |match|
    prefix = $1
    existing = $2
    suffix = $3

    if existing.strip.empty?
      "#{prefix}\n#{sources_entries.join("\n")}\n\t\t\t#{suffix}"
    else
      "#{prefix}#{existing.rstrip},\n#{sources_entries.join("\n")}\n\t\t\t#{suffix}"
    end
  end

  # 写回文件
  File.write(PROJECT_FILE, content)
  puts "\n✅ 已添加 #{files_to_add.length} 个文件到项目"
end

main
