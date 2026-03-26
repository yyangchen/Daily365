import Foundation
import AppKit
import UniformTypeIdentifiers

/// DataManager — 单例数据管理器
/// 核心数据序列化为 JSON，持久化存储在 App 沙盒 Documents 目录
/// 文件名：[daily365]_data.json
class FileStore {
    static let shared = FileStore()

    private let fileManager = FileManager.default
    private let documentsDir: URL
    private let legacyDir: URL
    private let entriesFileURL: URL
    private let legacyEntriesURL: URL

    // 防抖写入
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.5

    private init() {
        // 新路径：Documents 目录（用户可见，便于 iCloud 导出）
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        documentsDir = docs.appendingPathComponent("Daily365", isDirectory: true)
        entriesFileURL = documentsDir.appendingPathComponent("[daily365]_data.json")

        // 旧路径：Application Support（兼容迁移）
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        legacyDir = appSupport.appendingPathComponent("Daily365", isDirectory: true)
        legacyEntriesURL = legacyDir.appendingPathComponent("entries.json")

        // 确保目录存在
        try? fileManager.createDirectory(at: documentsDir, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: legacyDir, withIntermediateDirectories: true)

        // 数据迁移：如果旧位置有数据而新位置没有，自动迁移
        migrateIfNeeded()
    }

    /// 从旧路径迁移到新路径
    private func migrateIfNeeded() {
        guard fileManager.fileExists(atPath: legacyEntriesURL.path),
              !fileManager.fileExists(atPath: entriesFileURL.path) else { return }
        do {
            try fileManager.copyItem(at: legacyEntriesURL, to: entriesFileURL)
            print("[DataManager] Migrated data from Application Support to Documents")
        } catch {
            print("[DataManager] Migration failed: \(error)")
        }
    }

    // MARK: - 日记条目

    /// 保存日记条目（防抖）
    func saveEntries(_ jsonString: String) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.writeEntriesToDisk(jsonString)
        }
    }

    /// 立即写入（用于 App 退出时）
    func saveEntriesImmediately(_ jsonString: String) {
        writeEntriesToDisk(jsonString)
    }

    private func writeEntriesToDisk(_ jsonString: String) {
        do {
            try jsonString.write(to: entriesFileURL, atomically: true, encoding: .utf8)
            // 同时写入旧位置作为备份
            try? jsonString.write(to: legacyEntriesURL, atomically: true, encoding: .utf8)
            print("[DataManager] Saved to \(entriesFileURL.path)")
        } catch {
            print("[DataManager] Save error: \(error)")
        }
    }

    /// 读取日记条目
    func loadEntries() -> String {
        // 优先读新位置
        if fileManager.fileExists(atPath: entriesFileURL.path) {
            do {
                return try String(contentsOf: entriesFileURL, encoding: .utf8)
            } catch {
                print("[DataManager] Load error: \(error)")
            }
        }
        // 回退到旧位置
        if fileManager.fileExists(atPath: legacyEntriesURL.path) {
            do {
                return try String(contentsOf: legacyEntriesURL, encoding: .utf8)
            } catch {
                print("[DataManager] Legacy load error: \(error)")
            }
        }
        return ""
    }

    // MARK: - AI 配置

    /// 获取 AI 配置
    func getAIConfig() -> [String: String] {
        let defaults = UserDefaults.standard
        return [
            "provider": defaults.string(forKey: "daily365_ai_provider") ?? "deepseek",
            "apiKey": defaults.string(forKey: "daily365_api_key") ?? "",
            "customBaseUrl": defaults.string(forKey: "daily365_custom_base_url") ?? "",
            "customModelName": defaults.string(forKey: "daily365_custom_model_name") ?? ""
        ]
    }

    /// 保存 AI 配置
    func setAIConfig(_ config: [String: Any]) {
        let defaults = UserDefaults.standard
        if let provider = config["provider"] as? String {
            defaults.set(provider, forKey: "daily365_ai_provider")
        }
        if let apiKey = config["apiKey"] as? String {
            defaults.set(apiKey, forKey: "daily365_api_key")
        }
        if let customBaseUrl = config["customBaseUrl"] as? String {
            defaults.set(customBaseUrl, forKey: "daily365_custom_base_url")
        }
        if let customModelName = config["customModelName"] as? String {
            defaults.set(customModelName, forKey: "daily365_custom_model_name")
        }
    }

    // MARK: - 导出文件

    /// 保存导出文件（弹出原生保存对话框）
    func exportFile(content: String, filename: String) {
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = filename
            // 根据扩展名设置文件类型
            if filename.hasSuffix(".json") {
                panel.allowedContentTypes = [.json]
            } else if filename.hasSuffix(".doc") || filename.hasSuffix(".docx") {
                panel.allowedContentTypes = [UTType(filenameExtension: "doc") ?? .data]
            } else if filename.hasSuffix(".md") {
                panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
            } else {
                panel.allowedContentTypes = [.data]
            }
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                do {
                    try content.write(to: url, atomically: true, encoding: .utf8)
                    print("[DataManager] Exported to \(url.path)")
                } catch {
                    print("[DataManager] Export error: \(error)")
                }
            }
        }
    }

    /// 获取数据目录路径
    var dataDirectoryPath: String {
        return documentsDir.path
    }
}
