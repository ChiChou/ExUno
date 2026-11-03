import Foundation

struct DailyChoiceQuestion: Codable, Equatable {
    enum Kind: String, Codable, Hashable { case meaning, word, gap, listening }
    let kind: Kind
    let prompt: String
    let spoken: String
    let options: [String]
    let answer: String
    let explanation: String?
}

/// Reuses the bundled dictionary and Tatoeba grammar items. No network or generated translations.
enum DailyChallengeChoices {
    static func make(entries: [Entry], units: [GrammarUnit], levels: [String], day: Int,
                     language: LanguageCode) -> [Int: DailyChoiceQuestion] {
        var random = SeededRandom(seed: day &* 7919 &+ (LanguageCode.allCases.firstIndex(of: language) ?? 0) &* 31 &+ 701)
        let selectedLevels = Set(levels)
        let wordCounts = Dictionary(grouping: entries, by: { nativeKey($0.wordWithArticle) }).mapValues(\.count)
        let pool = entries.filter {
            selectedLevels.contains($0.level) && !$0.isPhrase &&
            ["noun", "verb", "adjective", "adverb"].contains($0.pos) &&
            !$0.word.isEmpty && $0.word.count <= 32 &&
            !$0.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.translation.count <= 72 &&
            wordCounts[nativeKey($0.wordWithArticle)] == 1
        }.sorted { $0.id < $1.id }.shuffled(using: &random)
        var result: [Int: DailyChoiceQuestion] = [:]
        var used = Set<Int>()

        for (slot, kind) in [(0, DailyChoiceQuestion.Kind.meaning), (2, .word), (4, .listening)] {
            for target in pool.prefix(64) where !used.contains(target.id) {
                let targetSenses = senses(target.translation)
                guard !targetSenses.isEmpty else { continue }
                let shuffled = pool.filter { $0.id != target.id }.shuffled(using: &random)
                // Plausible distractors first, without forcing tiny part-of-speech pools.
                let peers = shuffled.filter { $0.pos == target.pos } + shuffled.filter { $0.pos != target.pos }
                var choices = [target]
                var meanings = targetSenses
                var labels = Set([nativeKey(target.wordWithArticle)])
                for peer in peers {
                    let peerSenses = senses(peer.translation)
                    let label = nativeKey(peer.wordWithArticle)
                    guard !peerSenses.isEmpty, meanings.isDisjoint(with: peerSenses), !labels.contains(label) else { continue }
                    choices.append(peer)
                    meanings.formUnion(peerSenses)
                    labels.insert(label)
                    if choices.count == 4 { break }
                }
                guard choices.count == 4 else { continue }
                let reverse = kind == .word
                let options = choices.map { reverse ? $0.wordWithArticle : $0.translation }.shuffled(using: &random)
                let example = !target.exampleNative.isEmpty && !target.exampleEnglish.isEmpty
                    ? target.exampleNative + "\n" + target.exampleEnglish : nil
                result[slot] = DailyChoiceQuestion(kind: kind,
                    prompt: reverse ? target.translation : target.wordWithArticle,
                    spoken: target.spoken, options: options,
                    answer: reverse ? target.wordWithArticle : target.translation, explanation: example)
                used.insert(target.id)
                break
            }
        }

        let levelOrder = language == .la ? ["I", "II", "III", "IV"] : ["A1", "A2", "B1", "B2", "C1", "C2"]
        var available = units.filter { selectedLevels.contains($0.level) }
        // Advanced vocabulary packs extend beyond the bundled grammar course.
        if available.isEmpty, let ceiling = levels.compactMap({ levelOrder.firstIndex(of: $0) }).max(),
           let closest = units.compactMap({ levelOrder.firstIndex(of: $0.level) }).filter({ $0 <= ceiling }).max() {
            available = units.filter { $0.level == levelOrder[closest] }
        }
        let grammar = available.sorted { $0.id < $1.id }.flatMap(\.items).filter {
            $0.x.components(separatedBy: GrammarItem.gap).count == 2 && !$0.e.isEmpty &&
            !$0.a.isEmpty && $0.o.contains($0.a) && $0.o.count >= 2 &&
            $0.o.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) && Set($0.o).count == $0.o.count
        }
        if let item = grammar.shuffled(using: &random).first {
            result[3] = DailyChoiceQuestion(kind: .gap, prompt: item.x, spoken: item.sentence,
                options: item.o.shuffled(using: &random), answer: item.a, explanation: item.e)
        }
        return result
    }

    /// Drop usage annotations when comparing English senses, so "an (feminine)" cannot be a decoy for "an".
    private static func senses(_ translation: String) -> Set<String> {
        let bare = translation.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
        return Set(bare.components(separatedBy: CharacterSet(charactersIn: ",;/"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty })
    }

    private static func nativeKey(_ word: String) -> String {
        word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
