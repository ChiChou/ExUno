import AVFoundation
import Foundation

/// Text-to-speech in the current language, using the voices installed on the device.
@Observable
final class Speech: NSObject, AVSpeechSynthesizerDelegate {
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    private(set) var speakingID: String?
    var rate: Double = 0.95
    var language: LanguageCode = .it
    var voiceIdentifier: String = ""

    override init() {
        super.init()
        synthesizer.delegate = self
        // Audio-session calls can block, so keep them off the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try? AVAudioSession.sharedInstance().setActive(true, options: [])
        }
    }

    static func voices(for code: LanguageCode) -> [AVSpeechSynthesisVoice] {
        let prefix = String(code.speechLocale.prefix(2))
        return AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(prefix) }
            .sorted { ($0.quality.rawValue, $0.name) > ($1.quality.rawValue, $1.name) }
    }

    var selectedVoice: AVSpeechSynthesisVoice? {
        let voices = Self.voices(for: language)
        if let v = voices.first(where: { $0.identifier == voiceIdentifier }) { return v }
        let system = AVSpeechSynthesisVoice(language: language.speechLocale)
        let ordinary = voices.filter { !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice) }
        let local = ordinary.filter { $0.language == language.speechLocale }
        // Quality wins; for equal-quality voices, prefer Apple's language default
        // instead of selecting an arbitrary voice by reverse alphabetical name.
        return (local.isEmpty ? ordinary : local).sorted {
            if $0.quality != $1.quality { return $0.quality.rawValue > $1.quality.rawValue }
            let firstIsDefault = $0.identifier == system?.identifier
            let secondIsDefault = $1.identifier == system?.identifier
            if firstIsDefault != secondIsDefault { return firstIsDefault }
            return $0.name < $1.name
        }.first ?? system
    }

    /// `id` lets a button show a speaking state; any string unique to that button works.
    func speak(_ text: String, id: String = "") {
        stop()
        var cleaned = text.replacingOccurrences(of: " / ", with: ", ").replacingOccurrences(of: "/", with: " o ")
        if language == .la {
            // Latin is read by an Italian voice; macrons would confuse it.
            cleaned = cleaned.folding(options: .diacriticInsensitive, locale: Locale(identifier: "it"))
        }
        let u = AVSpeechUtterance(string: cleaned)
        u.voice = selectedVoice
        u.rate = Float(0.5 * rate)
        u.prefersAssistiveTechnologySettings = false
        speakingID = id
        synthesizer.speak(u)
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        speakingID = nil
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.speakingID = nil }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.speakingID = nil }
    }
}
