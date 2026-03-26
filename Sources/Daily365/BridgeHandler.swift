import Foundation
import WebKit
import AppKit

/// JS-Swift 桥接处理器
/// JS 端通过 window.webkit.messageHandlers.daily365.postMessage({action, payload, callbackId}) 调用
class BridgeHandler: NSObject, WKScriptMessageHandler {
    weak var coordinator: WebViewCoordinator?

    init(coordinator: WebViewCoordinator) {
        self.coordinator = coordinator
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else {
            print("[Bridge] Invalid message format")
            return
        }

        let payload = body["payload"]
        let callbackId = body["callbackId"] as? String ?? ""

        switch action {
        case "getAIConfig":
            handleGetAIConfig(callbackId: callbackId)

        case "setAIConfig":
            if let config = payload as? [String: Any] {
                handleSetAIConfig(config)
            }

        case "saveEntries":
            if let jsonData = payload as? String {
                handleSaveEntries(jsonData)
            }

        case "loadEntries":
            handleLoadEntries(callbackId: callbackId)

        case "exportFile":
            if let data = payload as? [String: Any],
               let content = data["content"] as? String,
               let filename = data["filename"] as? String {
                handleExportFile(content: content, filename: filename)
            }

        case "importFile":
            handleImportFile(callbackId: callbackId)

        case "startSpeech":
            handleStartSpeech()

        case "stopSpeech":
            handleStopSpeech()

        case "checkSpeechAvailable":
            handleCheckSpeechAvailable(callbackId: callbackId)

        case "fetchProxy":
            if let params = payload as? [String: Any] {
                handleFetchProxy(params, callbackId: callbackId)
            }

        case "log":
            // JS 端日志转发
            if let msg = payload as? String {
                print("[JS] \(msg)")
            }

        default:
            print("[Bridge] Unknown action: \\(action)")
        }
    }

    // MARK: - 原生语音识别

    private func handleCheckSpeechAvailable(callbackId: String) {
        SpeechRecognizer.shared.requestAuthorization { [weak self] authorized in
            self?.sendCallback(callbackId: callbackId, data: ["available": authorized])
        }
    }

    private func handleStartSpeech() {
        SpeechRecognizer.shared.requestAuthorization { [weak self] authorized in
            guard authorized else {
                self?.sendSpeechEvent(type: "error", text: "语音识别权限被拒绝，请在系统设置 > 隐私与安全性 > 语音识别中允许")
                return
            }

            SpeechRecognizer.shared.start(
                onResult: { [weak self] text, isFinal in
                    self?.sendSpeechEvent(type: isFinal ? "final" : "interim", text: text)
                },
                onError: { [weak self] errorMsg in
                    self?.sendSpeechEvent(type: "error", text: errorMsg)
                }
            )

            self?.sendSpeechEvent(type: "started", text: "")
        }
    }

    private func handleStopSpeech() {
        SpeechRecognizer.shared.stop()
        sendSpeechEvent(type: "stopped", text: "")
    }

    /// 向 JS 端发送语音识别事件
    private func sendSpeechEvent(type: String, text: String) {
        guard let webView = coordinator?.webView else { return }
        let escapedText = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        let js = "if(window.__onNativeSpeechEvent) window.__onNativeSpeechEvent('\(type)', '\(escapedText)');"
        DispatchQueue.main.async {
            webView.evaluateJavaScript(js) { _, error in
                if error != nil {
                    print("[Bridge] Speech event error: \(error!)")
                }
            }
        }
    }

    // MARK: - AI 配置

    private func handleGetAIConfig(callbackId: String) {
        let config = FileStore.shared.getAIConfig()
        let jsonData: [String: Any] = [
            "provider": config["provider"] ?? "deepseek",
            "apiKey": config["apiKey"] ?? "",
            "customBaseUrl": config["customBaseUrl"] ?? "",
            "customModelName": config["customModelName"] ?? ""
        ]

        sendCallback(callbackId: callbackId, data: jsonData)
    }

    private func handleSetAIConfig(_ config: [String: Any]) {
        FileStore.shared.setAIConfig(config)
    }

    // MARK: - 数据持久化

    private func handleSaveEntries(_ jsonData: String) {
        FileStore.shared.saveEntries(jsonData)
    }

    private func handleLoadEntries(callbackId: String) {
        let entries = FileStore.shared.loadEntries()
        sendCallback(callbackId: callbackId, data: ["entries": entries])
    }

    // MARK: - 导出

    private func handleExportFile(content: String, filename: String) {
        FileStore.shared.exportFile(content: content, filename: filename)
    }

    // MARK: - 导入

    private func handleImportFile(callbackId: String) {
        DispatchQueue.main.async { [weak self] in
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.json]
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.message = "选择 Daily365 备份文件"
            panel.begin { response in
                guard response == .OK, let url = panel.url else {
                    // 用户取消 — 小数据走 sendCallback 没问题
                    self?.sendCallback(callbackId: callbackId, data: ["cancelled": true])
                    return
                }
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    // 直接通过 evaluateJavaScript 注入文件内容到 JS，
                    // 绕过 sendCallback 的 JSON 序列化（避免大 JSON 双重转义）
                    guard let webView = self?.coordinator?.webView else { return }
                    let escaped = content
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "'", with: "\\'")
                        .replacingOccurrences(of: "\n", with: "\\n")
                        .replacingOccurrences(of: "\r", with: "\\r")
                    let js = "if(window.__daily365ProcessBackup) window.__daily365ProcessBackup('\(escaped)');"
                    webView.evaluateJavaScript(js) { _, error in
                        if let error = error {
                            print("[Bridge] Import inject error: \(error)")
                        }
                    }
                } catch {
                    self?.sendCallback(callbackId: callbackId, data: ["error": "读取文件失败: \(error.localizedDescription)"])
                }
            }
        }
    }

    // MARK: - 网络代理（绕过 WKWebView file:// CORS 限制）

    private func handleFetchProxy(_ params: [String: Any], callbackId: String) {
        guard let urlString = params["url"] as? String,
              let url = URL(string: urlString) else {
            sendCallback(callbackId: callbackId, data: ["error": "Invalid URL"])
            return
        }

        let method = (params["method"] as? String) ?? "GET"
        let headers = (params["headers"] as? [String: String]) ?? [:]
        let bodyString = params["body"] as? String

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let bodyString = bodyString, let bodyData = bodyString.data(using: .utf8) {
            request.httpBody = bodyData
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.sendCallback(callbackId: callbackId, data: ["error": error.localizedDescription])
                }
                return
            }

            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            let responseText = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

            DispatchQueue.main.async {
                self?.sendCallback(callbackId: callbackId, data: [
                    "status": statusCode,
                    "body": responseText
                ])
            }
        }.resume()
    }

    // MARK: - 回调

    private func sendCallback(callbackId: String, data: Any) {
        guard !callbackId.isEmpty, let webView = coordinator?.webView else { return }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            let escapedJSON = jsonString
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")

            let js = "if(window.daily365Callback) window.daily365Callback('\(callbackId)', '\(escapedJSON)');"
            DispatchQueue.main.async {
                webView.evaluateJavaScript(js) { _, error in
                    if error != nil {
                        print("[Bridge] Callback error: \(error!)")
                    }
                }
            }
        } catch {
            print("[Bridge] JSON serialization error: \\(error)")
        }
    }
}
