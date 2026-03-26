import Foundation
import Speech
import AVFoundation

/// 原生 macOS 语音识别（使用 Apple Speech 框架）
/// WKWebView 不支持 Web Speech API，改用原生实现后通过 JS 桥接调用
class SpeechRecognizer {
    static let shared = SpeechRecognizer()

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private var onResult: ((String, Bool) -> Void)?
    private var onError: ((String) -> Void)?

    var isRunning: Bool { audioEngine.isRunning }

    private init() {}

    /// 请求语音识别权限
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    /// 开始语音识别
    /// - Parameters:
    ///   - onResult: 回调 (文本, 是否为最终结果)
    ///   - onError: 错误回调
    func start(onResult: @escaping (String, Bool) -> Void, onError: @escaping (String) -> Void) {
        // 先停止之前的任务（stop() 会清空回调，所以必须在设置新回调之前调用）
        stop()

        // 设置新的回调（必须在 stop() 之后，否则会被 stop() 清空）
        self.onResult = onResult
        self.onError = onError

        // 检查识别器可用性
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            onError("语音识别服务不可用，请检查系统设置")
            return
        }

        // 创建识别请求
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else {
            onError("无法创建语音识别请求")
            return
        }
        request.shouldReportPartialResults = true

        // 启动识别任务
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                DispatchQueue.main.async {
                    self.onResult?(text, isFinal)
                }
            }

            if let error = error {
                let nsError = error as NSError
                // 忽略用户主动取消、识别被中断等非真正错误
                let ignoredCodes = [216, 209, 203, 301, 1110] // cancel, interrupted, no speech, etc.
                if nsError.domain == "kAFAssistantErrorDomain" && ignoredCodes.contains(nsError.code) {
                    return
                }
                // 也忽略通用 "cancelled" 错误
                if nsError.localizedDescription.lowercased().contains("cancel") {
                    return
                }
                DispatchQueue.main.async {
                    self.onError?(error.localizedDescription)
                    self.stop()
                }
            }
        }

        // 配置音频引擎
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            onError("启动录音失败：\(error.localizedDescription)")
            stop()
        }
    }

    /// 停止语音识别
    func stop() {
        // 先清除回调，避免 cancel() 触发的 error 回调向外传递
        onResult = nil
        onError = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}
