import SwiftUI
import AppKit

@main
struct Daily365App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            WebViewContainer()
                .frame(minWidth: 720, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 960, height: 680)
        .commands {
            // 文件菜单
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("导出数据…") {
                    NotificationCenter.default.post(name: .exportData, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command])

                Button("导入数据…") {
                    NotificationCenter.default.post(name: .importData, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hasConfiguredWindow = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 监听窗口创建/显示事件，确保窗口完全就绪后再配置
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeMain(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
        // 如果窗口已经存在，立即配置
        configureMainWindow()
    }

    @objc private func windowDidBecomeMain(_ notification: Notification) {
        configureMainWindow()
    }

    private func configureMainWindow() {
        guard !hasConfiguredWindow else { return }
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible || $0.isMainWindow }) ?? NSApplication.shared.windows.first else { return }

        hasConfiguredWindow = true

        // 标题栏透明（视觉上与内容区融为一体，标题栏区域仍可拖拽）
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
        window.minSize = NSSize(width: 720, height: 500)

        // 确保窗口可拖拽、可缩放
        window.isMovable = true
        window.styleMask.insert(.resizable)
        window.styleMask.insert(.titled)
        window.styleMask.insert(.fullSizeContentView)

        // 居中显示
        window.center()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// 自定义通知
extension Notification.Name {
    static let exportData = Notification.Name("daily365.exportData")
    static let importData = Notification.Name("daily365.importData")
}
