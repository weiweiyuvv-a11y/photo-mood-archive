import AVFoundation
import Speech

@MainActor
final class VoiceNoteRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isStarting = false
    @Published private(set) var transcript = ""
    @Published private(set) var statusText = ""
    private let engine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var hasTap = false
    private var session = UUID()
    private var interruptionObserver: NotificationObservation?

    init() {
        interruptionObserver = NotificationObservation(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stop(message: "语音输入已中断，已识别的文字会保留。") }
        })
    }

    func toggle() {
        if isRecording || isStarting { stop() }
        else { Task { await start() } }
    }

    func start() async {
        guard !isRecording, !isStarting else { return }
        isStarting = true
        let token = UUID(); session = token
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard session == token else { return }
        guard speech else { stop(message: "请在系统设置中开启语音识别权限。"); return }
        let mic = await AVAudioApplication.requestRecordPermission()
        guard session == token else { return }
        guard speech && mic else { stop(message: "请在系统设置中开启麦克风和语音识别权限。"); return }
        guard let recognizer, recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            stop(message: "这台设备暂不支持中文本地识别，可以直接输入文字。"); return
        }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            self.request = request
            transcript = ""
            let node = engine.inputNode
            let format = node.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { stop(message: "麦克风暂时不可用，请稍后重试。"); return }
            node.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable [weak request] buffer, _ in request?.append(buffer) }
            hasTap = true
            engine.prepare(); try engine.start()
            isStarting = false; isRecording = true; statusText = "正在听，点击结束即可保留文字。"
            recognition = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let final = result?.isFinal == true
                let errorText = error?.localizedDescription
                Task { @MainActor in
                    guard let self, self.session == token else { return }
                    if let text { self.transcript = text }
                    if let errorText { self.stop(message: "语音输入已结束：\(errorText)") }
                    else if final { self.stop(message: "语音已转为文字。") }
                }
            }
        } catch { stop(message: "无法启动语音输入，请稍后重试。") }
    }
    func stop(message: String = "") {
        session = UUID()
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
        request?.endAudio(); recognition?.cancel()
        request = nil; recognition = nil
        isStarting = false; isRecording = false; statusText = message
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private final class NotificationObservation: @unchecked Sendable {
    let token: NSObjectProtocol
    init(_ token: NSObjectProtocol) { self.token = token }
    deinit { NotificationCenter.default.removeObserver(token) }
}
