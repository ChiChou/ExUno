import AVFoundation
import SwiftUI

struct MeView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(Speech.self) private var speech
    @State private var confirmReset = false
    @State private var showLanguages = false

    var body: some View {
        @Bindable var progress = progress
        let s = progress.strings
        let total = progress.pack.log.values.reduce(0) { $0 + $1.reviews }
        let good = progress.pack.log.values.reduce(0) { $0 + $1.good }
        let voices = Speech.voices(for: progress.language)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(s.me).font(Theme.display(34))
                Button { showLanguages = true } label: { LanguageRow(code: progress.language, selected: false, compact: true).overlay(alignment: .trailing) {
                    Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.bold)).foregroundStyle(Theme.ink2).padding(.trailing, 14)
                } }.buttonStyle(.plain)
                HStack(spacing: 8) {
                    StatTile(value: "\(progress.streak)", label: s.streak)
                    StatTile(value: "\(total)", label: s.cards.lowercased())
                    StatTile(value: total > 0 ? "\(Int((Double(good) / Double(total) * 100).rounded()))%" : "–", label: s.good.lowercased())
                }
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("14").font(.caption.weight(.bold)).foregroundStyle(Theme.ink2)
                            Spacer()
                            Hint(text: "\(progress.pack.cards.count) · \(progress.pack.cards.values.filter { $0.interval >= 7 }.count) \(s.solid)")
                        }
                        HistoryChart(log: progress.pack.log)
                    }
                }

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
                        Divider()
                        settingRow("Speech rate") {
                            Picker("", selection: Binding(get: { progress.app.rate }, set: { progress.app.rate = $0; speech.rate = $0; speech.speak(progress.language.hello) })) {
                                Text("Slow").tag(0.7); Text("Relaxed").tag(0.85); Text("Natural").tag(0.95); Text("Fast").tag(1.1)
                            }
                        }
                        if progress.language.usesEuro {
                            Divider()
                            settingRow("Home currency") {
                                Picker("", selection: $progress.app.currency) {
                                    ForEach(["USD", "GBP", "CHF", "JPY", "CNY", "CAD", "AUD", "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "BRL", "MXN", "INR", "KRW", "SGD", "HKD", "NZD", "ZAR", "TRY"], id: \.self) { Text($0).tag($0) }
                                }
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
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showLanguages) { LanguagePicker().presentationDetents([.height(460), .large]) }
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
        let q = v.quality == .premium ? " (Premium)" : v.quality == .enhanced ? " (Enhanced)" : ""
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

struct HistoryChart: View {
    let log: [Int: DayLog]
    var body: some View {
        let today = StudyProgress.today()
        let days = (0..<14).map { today - 13 + $0 }
        let maxN = max(1, days.map { log[$0]?.reviews ?? 0 }.max() ?? 1)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(days, id: \.self) { d in
                let n = log[d]?.reviews ?? 0
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(d == today ? Theme.amber : Theme.accent)
                        .frame(height: n > 0 ? max(4, CGFloat(n) / CGFloat(maxN) * 60) : 2)
                        .frame(maxHeight: 60, alignment: .bottom)
                    Text(dayLabel(d)).font(.system(size: 9)).foregroundStyle(Theme.ink2)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 80)
    }
    private func dayLabel(_ day: Int) -> String {
        let date = Date(timeIntervalSince1970: Double(day) * 86_400 - Double(TimeZone.current.secondsFromGMT()) + 43_200)
        return "\(Calendar.current.component(.day, from: date))"
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
                section("Spanish and French", "Language-Learning-decks Spanish and French decks (© 2025 GENERAL NEURO, MIT) with wordfreq frequencies (CC BY-SA 4.0, Robyn Speer). Articles come from the decks' own example sentences; topics are projected from the Italian tags through shared English glosses.", [
                    ("Language-Learning-decks", "https://github.com/vbvss199/Language-Learning-decks"),
                    ("wordfreq", "https://github.com/rspeer/wordfreq"),
                ])
                section("Latin", "Dickinson College Commentaries Latin Core Vocabulary (CC BY-SA), the ~1,000 most frequent words with principal parts and semantic groups, compiled by Christopher Francese and collaborators.", [
                    ("DCC Latin Core Vocabulary", "https://dcc.dickinson.edu/latin-vocabulary-list"),
                    ("DCC terms of use", "https://dcc.dickinson.edu/terms-use"),
                ])
                section("Grammar courses", "Example sentences from Tatoeba (Tatoeba contributors, CC BY 2.0 FR), via the OPUS release v2026-07-08. Verb and noun paradigms from UniMorph (CC BY-SA 3.0, extracted from English Wiktionary); Latin verb forms from the app's own rules with DCC principal parts. Unit notes and tables are written for Ex Uno.", [
                    ("Tatoeba", "https://tatoeba.org/"),
                    ("Tatoeba terms of use", "https://tatoeba.org/en/terms_of_use"),
                    ("OPUS Tatoeba", "https://opus.nlpl.eu/Tatoeba/corpus/version/Tatoeba"),
                    ("UniMorph", "https://unimorph.github.io/"),
                    ("CC BY 2.0 FR", "https://creativecommons.org/licenses/by/2.0/fr/"),
                    ("CC BY-SA 3.0", "https://creativecommons.org/licenses/by-sa/3.0/"),
                ])
                section("Online", "Word definitions from the Wiktionary REST API (Wiktionary contributors, CC BY-SA 4.0). Exchange rates are European Central Bank reference rates served by Frankfurter.", [
                    ("Wiktionary", "https://en.wiktionary.org/"),
                    ("Frankfurter", "https://frankfurter.dev/"),
                    ("ECB reference rates", "https://www.ecb.europa.eu/stats/policy_and_exchange_rates/euro_reference_exchange_rates/html/index.en.html"),
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
