import Foundation
import AVFoundation
import whisper

/*
 * Hold-to-talk (UX upgrades 26 Oct 2026, section 9): the microphone records while the button is held; on release the
 * words are turned to text on the phone by whisper.cpp with the downloaded pack (VoicePack), in Uzbek or Russian by the
 * app's language, and VoiceParse makes millimetres of them. Nothing leaves the phone.
 */
final class VoiceEngine {
    static let shared = VoiceEngine()

    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private var rate: Double = 16_000
    private let lock = NSLock()
    private var recording = false
    private var ctx: OpaquePointer? = nil
    private let work = DispatchQueue(label: "metrx.voice", qos: .userInitiated)

    /// Asks for the microphone once; done(true) when it may be used.
    func permission(_ done: @escaping (Bool) -> Void) {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: done(true)
        case .denied: done(false)
        default: AVAudioApplication.requestRecordPermission { ok in DispatchQueue.main.async { done(ok) } }
        }
    }

    /// Starts recording; false when the microphone cannot be used.
    func start() -> Bool {
        if recording { return true }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: [])
        } catch { return false }
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0 else { return false }
        rate = fmt.sampleRate
        lock.lock(); samples = []; lock.unlock()
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: fmt) { [weak self] buf, _ in
            guard let self, let ch = buf.floatChannelData else { return }
            let n = Int(buf.frameLength)
            let p = UnsafeBufferPointer(start: ch[0], count: n)
            self.lock.lock(); self.samples.append(contentsOf: p); self.lock.unlock()
        }
        do { engine.prepare(); try engine.start() } catch { input.removeTap(onBus: 0); return false }
        recording = true
        // the model loads while the words are said
        work.async { [weak self] in self?.load() }
        return true
    }

    /// Stops recording and gives the text heard (nil: nothing, or no pack).
    func stop(_ done: @escaping (String?) -> Void) {
        guard recording else { done(nil); return }
        recording = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        lock.lock(); let raw = samples; samples = []; lock.unlock()
        let r = rate
        let lang = AppSettings.shared.lang
        work.async { [weak self] in
            let text = self?.recognize(VoiceEngine.resample(raw, from: r), lang)
            DispatchQueue.main.async { done(text) }
        }
    }

    /// The pack was deleted: the model goes too.
    func unload() { work.async { [weak self] in if let c = self?.ctx { whisper_free(c); self?.ctx = nil } } }

    private func load() {
        if ctx != nil { return }
        let path = VoicePack.file.path
        guard FileManager.default.fileExists(atPath: path) else { return }
        var cp = whisper_context_default_params()
        #if targetEnvironment(simulator)
        cp.use_gpu = false
        #endif
        ctx = whisper_init_from_file_with_params(path, cp)
    }

    private func recognize(_ pcm: [Float], _ lang: Lang) -> String? {
        load()
        guard let ctx, pcm.count > 1600 else { return nil }
        var p = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        p.print_realtime = false; p.print_progress = false; p.print_timestamps = false; p.print_special = false
        p.translate = false; p.no_context = true; p.single_segment = true; p.no_timestamps = true
        p.n_threads = Int32(max(1, min(4, ProcessInfo.processInfo.activeProcessorCount - 1)))
        let code = lang == .ru ? "ru" : lang == .en ? "auto" : "uz"
        // the numbers' words, so the model expects them
        let hint = lang == .ru ? "Размер: три тысячи четыреста миллиметров, два с половиной метра, семьдесят сантиметров."
                               : "O‘lcham: uch ming to‘rt yuz millimetr, ikki yarim metr, yetmish santimetr, olti yuz."
        var out = ""
        code.withCString { l in
            hint.withCString { h in
                p.language = l
                p.initial_prompt = h
                pcm.withUnsafeBufferPointer { b in _ = whisper_full(ctx, p, b.baseAddress, Int32(b.count)) }
            }
        }
        let n = whisper_full_n_segments(ctx)
        for i in 0..<n { if let t = whisper_full_get_segment_text(ctx, i) { out += String(cString: t) } }
        let t = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// Mono samples at rate r to 16 kHz (linear), what whisper reads.
    static func resample(_ x: [Float], from r: Double) -> [Float] {
        if x.isEmpty { return [] }
        if abs(r - 16_000) < 1 { return x }
        let k = r / 16_000
        let n = Int(Double(x.count) / k)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) * k
            let a = Int(t), f = Float(t - Double(a))
            let b = min(a + 1, x.count - 1)
            out[i] = x[a] * (1 - f) + x[b] * f
        }
        return out
    }
}
