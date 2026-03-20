import Foundation

// MARK: - 应用发行版本区分
//
// 编译时通过 Swift Active Compilation Conditions 区分：
//   App Store 版：添加 "APP_STORE_BUILD" 条件
//   Direct 版：不添加该条件（默认）
//
// Xcode 设置路径：Build Settings → Swift Compiler - Custom Flags → Active Compilation Conditions

/// 应用发行版本类型
enum AppVariant {

    // MARK: - 版本判断

    /// 当前是否为 App Store 版本
    static var isAppStoreBuild: Bool {
        #if APP_STORE_BUILD
        return true
        #else
        return false
        #endif
    }

    // MARK: - 功能开关

    /// 是否支持 SSH Agent 认证（需要访问 SSH_AUTH_SOCK，App Store 沙箱禁止）
    static var supportsSSHAgent: Bool {
        #if APP_STORE_BUILD
        return false
        #else
        return true
        #endif
    }

    /// 是否支持本地文件系统直接访问（绕过沙箱）
    static var supportsUnrestrictedFileAccess: Bool {
        #if APP_STORE_BUILD
        return false
        #else
        return true
        #endif
    }

    // MARK: - 版本名称

    static var buildVariantName: String {
        #if APP_STORE_BUILD
        return "App Store"
        #else
        return "Direct"
        #endif
    }
}
