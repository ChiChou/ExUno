import AVFoundation
import SwiftUI

/// Study and app settings, opened from the gear on Today.
struct SettingsView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Speech.self) private var speech
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var voiceRefresh = 0

    var body: some View {
        @Bindable var progress = progress
        let _ = voiceRefresh
        let voices = Speech.voices(for: progress.language)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Card { LevelRangeControl() }
                    Card(padding: 4) {
                        VStack(spacing: 0) {
                            settingRow("Daily goal") {
                                Picker("", selection: $progress.app.goal) { ForEach([10, 15, 20, 30, 40, 60], id: \.self) { Text("\($0)").tag($0) } }
                            }
                            Divider()
                            settingRow("New words per day") {
                                Picker("", selection: $progress.app.newPerDay) { ForEach([5, 10, 15, 20, 30], id: \.self) { Text("\($0)").tag($0) } }
                            }
                            Divider()
                            settingRow(voices.isEmpty ? "Voice (none installed)" : "Voice") {
                                Picker("", selection: Binding(get: { progress.app.voices[progress.language.rawValue] ?? "" },
                                                              set: { progress.app.voices[progress.language.rawValue] = $0; speech.voiceIdentifier = $0; speech.speak(progress.language.hello) })) {
                                    Text("Automatic").tag("")
                                    ForEach(voices, id: \.identifier) { Text(voiceName($0)).tag($0.identifier) }
                                }
                            }
                            if let voice = speech.selectedVoice {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Using \(voiceName(voice)) · \(voice.language)")
                                        .font(.footnote).foregroundStyle(Theme.ink2)
                                    if voice.quality == .default {
                                        Text("For clearer speech, download an Enhanced or Premium voice for this language in iPhone Accessibility settings. Installed voices work offline.")
                                            .font(.footnote).foregroundStyle(Theme.ink2)
                                    }
                                    Button {
                                        let sample = progress.engine.clockCard(Date())
                                        speech.speak(sample.headline + ". " + sample.line)
                                    } label: { Label("Test pronunciation", systemImage: "speaker.wave.2") }
                                        .font(.subheadline.weight(.medium)).tint(Theme.accent)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12).padding(.bottom, 12)
                            }
                            Divider()
                            settingRow("Speech rate") {
                                Picker("", selection: Binding(get: { progress.app.rate }, set: { progress.app.rate = $0; speech.rate = $0; speech.speak(progress.language.hello) })) {
                                    Text("Slow").tag(0.7); Text("Relaxed").tag(0.85); Text("Natural").tag(0.95); Text("Fast").tag(1.1)
                                }
                            }
                            Divider()
                            HStack {
                                Image(systemName: progress.cloud.isAvailable ? "icloud" : "icloud.slash").foregroundStyle(progress.cloud.isAvailable ? Theme.green : Theme.ink2)
                                Text(progress.cloud.isAvailable ? "Synced with iCloud" : "Sign in to iCloud to sync").font(.subheadline)
                                Spacer()
                            }
                            .padding(.horizontal, 12).padding(.vertical, 12)
                        }
                    }

                    VStack(spacing: 0) {
                        NavigationLink { LicensesScreen() } label: { linkRow("Data & licenses") }.buttonStyle(.plain)
                        Divider().padding(.leading, 14)
                        Button {
                            if confirmReset { progress.resetCurrentLanguage(); confirmReset = false }
                            else { confirmReset = true; DispatchQueue.main.asyncAfter(deadline: .now() + 4) { confirmReset = false } }
                        } label: {
                            HStack {
                                Text(confirmReset ? "Tap again to reset \(progress.language.englishName)" : "Reset \(progress.language.englishName) progress").foregroundStyle(Theme.red)
                                Spacer()
                            }.padding(14).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.rule, lineWidth: 1))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .pageBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVSpeechSynthesizer.availableVoicesDidChangeNotification)) { _ in
            voiceRefresh += 1
        }
    }

    private func linkRow(_ title: String) -> some View {
        HStack {
            Text(title).fontWeight(.semibold).foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.ink2)
        }
        .padding(14).contentShape(Rectangle())
    }

    private func voiceName(_ v: AVSpeechSynthesisVoice) -> String {
        let q = v.quality == .premium ? " (Premium)" : v.quality == .enhanced ? " (Enhanced)" : " (Standard)"
        return v.name.replacingOccurrences(of: "\\(.*?\\)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces) + q
    }

    private func settingRow<C: View>(_ title: String, @ViewBuilder control: () -> C) -> some View {
        HStack(spacing: 12) {
            Text(title).fontWeight(.semibold)
            Spacer()
            control().labelsHidden().tint(Theme.ink)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}

struct LicensesScreen: View {
    private typealias L = (String, String)
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section("Italian", "Language-Learning-decks Italian deck (© 2025 GENERAL NEURO, MIT) with wordfreq frequencies (CC BY-SA 4.0, Robyn Speer). Articles come from the deck's own example sentences. Topics from MultiWordNet (CC BY 3.0) and Princeton WordNet 3.0 via Open Multilingual Wordnet 2.0.", [
                    ("Language-Learning-decks", "https://github.com/vbvss199/Language-Learning-decks"),
                    ("wordfreq", "https://github.com/rspeer/wordfreq"),
                    ("Open Multilingual Wordnet 2.0", "https://github.com/omwn/omw-data/releases/tag/v2.0"),
                    ("MultiWordNet", "https://multiwordnet.fbk.eu/"),
                    ("Princeton WordNet", "https://wordnet.princeton.edu/"),
                ])
                section("Spanish, French and Portuguese", "Language-Learning-decks Spanish, French and European Portuguese decks (© 2025 GENERAL NEURO, MIT) with wordfreq frequencies (CC BY-SA 4.0, Robyn Speer). Articles come from the decks' own example sentences; topics are projected from the Italian tags through shared English glosses.", [
                    ("Language-Learning-decks", "https://github.com/vbvss199/Language-Learning-decks"),
                    ("wordfreq", "https://github.com/rspeer/wordfreq"),
                ])
                section("Latin", "Dickinson College Commentaries Latin Core Vocabulary (CC BY-SA), the ~1,000 most frequent words with principal parts and semantic groups, compiled by Christopher Francese and collaborators.", [
                    ("DCC Latin Core Vocabulary", "https://dcc.dickinson.edu/latin-vocabulary-list"),
                    ("DCC terms of use", "https://dcc.dickinson.edu/terms-use"),
                ])
                section("Grammar courses", "Example sentences from Tatoeba (Tatoeba contributors, CC BY 2.0 FR), via the OPUS release v2026-07-08. Verb and noun paradigms from UniMorph (CC BY-SA 3.0, from English Wiktionary, or Wikipedia for Portuguese as credited by UniMorph por); Portuguese verb tables are bundled from UniMorph; Latin verb forms from the app's own rules with DCC principal parts. Unit notes and tables are written for Ex Uno.", [
                    ("Tatoeba", "https://tatoeba.org/"),
                    ("Tatoeba terms of use", "https://tatoeba.org/en/terms_of_use"),
                    ("OPUS Tatoeba", "https://opus.nlpl.eu/Tatoeba/corpus/version/Tatoeba"),
                    ("UniMorph", "https://unimorph.github.io/"),
                    ("CC BY 2.0 FR", "https://creativecommons.org/licenses/by/2.0/fr/"),
                    ("CC BY-SA 3.0", "https://creativecommons.org/licenses/by-sa/3.0/"),
                ])
                section("Online", "Everything works offline. When you're online, the Wiktionary button in Words fetches definitions from the Wiktionary REST API (Wiktionary contributors, CC BY-SA 4.0).", [
                    ("Wiktionary", "https://en.wiktionary.org/"),
                ])
                section("Speech", "The voices installed on this device. Latin is read by an Italian voice.", [])
                section("Rules", "Number, time, date, calendar and verb rules are written by the app and cover standard usage; regional habits vary and rare irregular verbs may be wrong. Levels are teaching estimates, not CEFR certifications.", [])
                section("Licenses", "Ex Uno's code is MIT-licensed. The vocabulary packs and grammar courses are shared under CC BY-SA 4.0; full notices are in ATTRIBUTIONS.md.", [
                    ("Source code and data scripts", AppInfo.repository),
                    ("CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0/"),
                    ("CC BY 3.0", "https://creativecommons.org/licenses/by/3.0/"),
                    ("WordNet 3.0 license", "https://wordnet.princeton.edu/license-and-commercial-use"),
                ])
            }
            .padding(16)
        }
        .pageBackground()
        .navigationTitle("Data & licenses")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func section(_ title: String, _ text: String, _ links: [L]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(Theme.ink2)
                if !links.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(links, id: \.1) { link in
                            if let url = URL(string: link.1) {
                                Link(destination: url) {
                                    Label(link.0, systemImage: "arrow.up.right.square").font(.footnote.weight(.medium))
                                }
                                .tint(Theme.accent)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }
}
