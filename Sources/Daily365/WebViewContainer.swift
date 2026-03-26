import SwiftUI
import WebKit

// MARK: - iOS 适配条件编译预留
// #if os(iOS)
// import UIKit
// typealias ViewRepresentable = UIViewRepresentable
// #else
// typealias ViewRepresentable = NSViewRepresentable
// #endif

struct WebViewContainer: NSViewRepresentable {
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // 允许本地文件 JS 访问
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        // 注册 JS-Swift 桥接
        let handler = BridgeHandler(coordinator: context.coordinator)
        config.userContentController.add(handler, name: "daily365")

        // 注入桥接就绪标志的用户脚本
        let bridgeReadyScript = WKUserScript(
            source: """
            window.__daily365BridgeReady = true;
            // macOS App: 标题栏由系统管理，不需要额外偏移
            document.documentElement.style.setProperty('--titlebar-height', '0px');
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(bridgeReadyScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // 透明背景
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        context.coordinator.webView = webView
        webView.uiDelegate = context.coordinator

        // 加载本地 HTML
        if let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }

        // 监听导出/导入通知
        NotificationCenter.default.addObserver(
            forName: .exportData, object: nil, queue: .main
        ) { _ in
            context.coordinator.triggerExport()
        }
        NotificationCenter.default.addObserver(
            forName: .importData, object: nil, queue: .main
        ) { _ in
            context.coordinator.triggerImport()
        }

        // 启动时恢复数据
        context.coordinator.restoreDataOnLoad()

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - Coordinator
class WebViewCoordinator: NSObject, WKUIDelegate {
    weak var webView: WKWebView?
    private var hasRestoredData = false

    // MARK: - WKUIDelegate — alert()
    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "确定")
        alert.runModal()
        completionHandler()
    }

    // MARK: - WKUIDelegate — confirm()
    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn)
    }

    // MARK: - WKUIDelegate — prompt()
    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = prompt
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = defaultText ?? ""
        alert.accessoryView = input
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn ? input.stringValue : nil)
    }

    func restoreDataOnLoad() {
        // WebView 加载完成后注入本地文件数据
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.injectStoredData()
        }
    }

    func injectStoredData() {
        guard let webView = webView else { return }

        // 从本地文件读取数据并注入到 IndexedDB
        let entries = FileStore.shared.loadEntries()
        guard !entries.isEmpty else { return }

        let escapedJSON = entries
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")

        let js = """
        (function() {
            if (window.__daily365RestoreFromNative) {
                window.__daily365RestoreFromNative('\(escapedJSON)');
            }
        })();
        """
        webView.evaluateJavaScript(js) { _, error in
            if error != nil {
                print("[Daily365] Data restore error: \(error!)")
            }
        }
    }

    func triggerExport() {
        webView?.evaluateJavaScript("if(window.__daily365TriggerExport) window.__daily365TriggerExport();")
    }

    func triggerImport() {
        // 打开文件选择对话框
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            if let data = try? String(contentsOf: url, encoding: .utf8) {
                let escapedData = data
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                    .replacingOccurrences(of: "\n", with: "\\n")
                self?.webView?.evaluateJavaScript(
                    "if(window.__daily365TriggerImport) window.__daily365TriggerImport('\(escapedData)');"
                )
            }
        }
    }
}
