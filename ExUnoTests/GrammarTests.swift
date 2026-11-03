import XCTest
@testable import ExUno

final class GrammarModelTests: XCTestCase {
    private let fixture = """
    {"code":"it","schema":1,"license":"CC BY-SA 4.0","attribution":"test","levels":["A1"],
     "units":[{"id":"it-test","level":"A1","title":"Prova","en":"Test","note":"…",
               "table":{"cols":["","essere"],"rows":[["io","sono"]]},
               "items":[{"x":"Io ___ stanco.","a":"sono","o":["sei","sono","è"],"e":"I'm tired.","g":"essere · io","k":"essere/0"},
                        {"x":"___intrusione.","a":"l'","o":["il","l'","la"],"e":"The intrusion.","h":"x","g":"sing.","k":"def/2"}]}]}
    """

    func testDecodeAndGap() throws {
        let course = try JSONDecoder().decode(GrammarCourseFile.self, from: Data(fixture.utf8))
        let unit = try XCTUnwrap(course.units.first)
        XCTAssertEqual(unit.table?.rows.first, ["io", "sono"])
        let item = unit.items[0]
        XCTAssertEqual(item.before, "Io ")
        XCTAssertEqual(item.after, " stanco.")
        XCTAssertEqual(item.sentence, "Io sono stanco.")
        XCTAssertEqual(item.filled(with: "sei"), "Io sei stanco.")
        XCTAssertEqual(item.row, "essere")
        XCTAssertEqual(item.column, 0)
        XCTAssertNil(item.h)
        XCTAssertEqual(unit.items[1].sentence, "l'intrusione.")
        XCTAssertEqual(unit.items[1].column, 2)
    }

    private func unit(_ n: Int) -> GrammarUnit {
        GrammarUnit(id: "u", level: "A1", title: "", en: "", note: "", table: nil,
                    items: (0..<n).map { GrammarItem(x: "\($0) ___", a: "a\($0)", o: ["a\($0)", "b"], e: "", h: nil, g: "", k: "r/0") })
    }

    func testRoundRotatesThroughItems() {
        XCTAssertEqual(GrammarRound(unit: unit(25), run: 0).items.map(\.a), (0..<10).map { "a\($0)" })
        XCTAssertEqual(GrammarRound(unit: unit(25), run: 1).items.first?.a, "a10")
        XCTAssertEqual(GrammarRound(unit: unit(25), run: 2).items.map(\.a), ["a20", "a21", "a22", "a23", "a24", "a0", "a1", "a2", "a3", "a4"])
        XCTAssertEqual(GrammarRound(unit: unit(4), run: 3).items.count, 4)
        XCTAssertTrue(GrammarRound(unit: unit(0), run: 0).isFinished)
    }

    func testRoundScoring() {
        var r = GrammarRound(unit: unit(3), run: 0)
        XCTAssertTrue(r.choose("a0"))
        XCTAssertFalse(r.choose("b"), "a second tap must not change the answer")
        XCTAssertTrue(r.wasCorrect)
        r.advance()
        XCTAssertFalse(r.answered)
        r.advance()                       // ignored until the item is answered
        XCTAssertEqual(r.index, 1)
        XCTAssertFalse(r.choose("b"))
        XCTAssertFalse(r.wasCorrect)
        r.advance()
        r.choose("a2"); r.advance()
        XCTAssertTrue(r.isFinished)
        XCTAssertEqual(r.correct, 2)
        XCTAssertNil(r.current)
    }

    func testProgressWithoutGrammarStillDecodesAndMerges() throws {
        let old = try JSONEncoder().encode(PackProgress())
        var dict = try XCTUnwrap(JSONSerialization.jsonObject(with: old) as? [String: Any])
        dict.removeValue(forKey: "grammar")
        let p = try JSONDecoder().decode(PackProgress.self, from: JSONSerialization.data(withJSONObject: dict))
        XCTAssertNil(p.grammar)

        var a = PackProgress(), b = PackProgress()
        a.grammar = ["x": LessonScore(best: 9, runs: 1, lastDay: 10)]
        b.grammar = ["x": LessonScore(best: 6, runs: 3, lastDay: 12), "y": LessonScore(best: 8, runs: 1, lastDay: 5)]
        let m = a.merged(with: b)
        XCTAssertEqual(m.grammar?["x"], LessonScore(best: 9, runs: 3, lastDay: 12))
        XCTAssertEqual(m.grammar?["y"]?.passed, true)
        XCTAssertEqual(PackProgress().merged(with: b).grammar, b.grammar)
        XCTAssertEqual(a.merged(with: PackProgress()).grammar, a.grammar)
    }
}

/// Checks the generated courses in the app bundle (Scripts/prepare_data.sh). Skipped when they aren't built.
final class GrammarCourseDataTests: XCTestCase {
    private func course(_ code: LanguageCode) throws -> GrammarCourseFile {
        let name = "grammar-\(code.rawValue)"
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Packs") ?? Bundle.main.url(forResource: name, withExtension: "json") else {
            throw XCTSkip("\(name).json is not in the bundle; run sh Scripts/prepare_data.sh")
        }
        return try JSONDecoder().decode(GrammarCourseFile.self, from: Data(contentsOf: url))
    }

    private func vocabulary(_ code: LanguageCode) throws -> LanguagePackFile {
        guard let url = Bundle.main.url(forResource: code.rawValue, withExtension: "json", subdirectory: "Packs") ?? Bundle.main.url(forResource: code.rawValue, withExtension: "json") else {
            throw XCTSkip("\(code.rawValue).json is not in the bundle")
        }
        return try JSONDecoder().decode(LanguagePackFile.self, from: Data(contentsOf: url))
    }

    private func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en")).lowercased().replacingOccurrences(of: "j", with: "i")
    }

    func testEveryItemIsAnswerable() throws {
        for code in LanguageCode.allCases {
            let c = try course(code)
            XCTAssertEqual(c.code, code.rawValue)
            XCTAssertEqual(c.license, "CC BY-SA 4.0")
            XCTAssertGreaterThanOrEqual(c.units.count, 10, code.rawValue)
            XCTAssertEqual(Set(c.units.map(\.id)).count, c.units.count, "unit ids must be unique (progress is keyed on them)")
            for u in c.units {
                XCTAssertTrue(c.levels.contains(u.level), u.id)
                XCTAssertGreaterThanOrEqual(u.items.count, GrammarRound.size, u.id)
                XCTAssertFalse(u.note.isEmpty, u.id)
                for item in u.items {
                    XCTAssertEqual(item.x.components(separatedBy: GrammarItem.gap).count, 2, "\(u.id): \(item.x)")
                    XCTAssertTrue(item.o.contains(item.a), "\(u.id): \(item.x)")
                    XCTAssertGreaterThanOrEqual(item.o.count, 3, "\(u.id): \(item.x)")
                    XCTAssertEqual(Set(item.o.map { fold($0) }).count, item.o.count, "\(u.id): options differ only in accents: \(item.o)")
                    XCTAssertFalse(item.e.isEmpty, "\(u.id): \(item.x)")
                }
            }
        }
    }

    /// The Latin verb items come from a Python port of LatinConjugator; both must give the same forms.
    func testLatinVerbItemsMatchTheConjugator() throws {
        let c = try course(.la), vocab = try vocabulary(.la)
        let tenses = ["PRS": "Praesēns", "IPFV": "Imperfectum", "FUT": "Futūrum", "PRF": "Perfectum"]
        var checked = 0
        for u in c.units {
            for item in u.items {
                guard let tense = tenses[item.row], let col = item.column, let lemma = item.h,
                      let entry = vocab.entries.first(where: { $0.w == lemma && $0.p == "verb" }) else { continue }
                if entry.m?.contains("/") == true { continue }   // LatinConjugator keeps "-īvī/-iī" alternatives verbatim
                let forms = LatinConjugator.conjugate(lemma, hint: entry.verbHint, pronouns: [])?.tenses.first { $0.name == tense }?.forms
                let form = try XCTUnwrap(forms?[safe: col], "\(u.id): \(lemma) has no \(tense)")
                XCTAssertEqual(fold(form), fold(item.a), "\(u.id): \(lemma) \(tense) \(col)")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 100)
    }

    /// Romance verb items come from UniMorph (Wiktionary). The app's rule-based conjugators should agree on nearly all of them.
    func testRomanceVerbItemsAgreeWithTheConjugators() throws {
        let tenses: [LanguageCode: [String: String]] = [
            .it: ["prs": "Presente", "ipfv": "Imperfetto", "fut": "Futuro semplice"],
            .es: ["prs": "Presente", "pfv": "Pretérito indefinido", "ipfv": "Imperfecto", "fut": "Futuro"],
            .fr: ["prs": "Présent", "ipfv": "Imparfait", "fut": "Futur simple"],
            .esLatAm: ["prs": "Presente", "pfv": "Pretérito indefinido", "ipfv": "Imperfecto", "fut": "Futuro"],
            .ptBR: ["presente": "Presente", "perfeito": "Pretérito perfeito", "imperfeito": "Imperfeito", "futuro": "Futuro", "condicional": "Condicional", "conjuntivo": "Presente do subjuntivo"],
            .pt: ["presente": "Presente", "perfeito": "Pretérito perfeito", "imperfeito": "Imperfeito", "futuro": "Futuro", "condicional": "Condicional", "conjuntivo": "Presente do conjuntivo"],
        ]
        for (code, names) in tenses {
            let c = try course(code)
            var agree = 0, total = 0, misses: [String] = []
            for u in c.units {
                for item in u.items {
                    guard let tense = names[item.row], let col = item.column, let lemma = item.h,
                          let form = code.engine.conjugate(lemma, hint: nil)?.tenses.first(where: { $0.name == tense })?.forms[safe: col] else { continue }
                    let last = form.split(whereSeparator: { $0 == " " || $0 == "'" }).last.map(String.init) ?? form
                    total += 1
                    if last.lowercased() == item.a.lowercased() { agree += 1 } else { misses.append("\(lemma) \(tense) \(col): \(item.a) vs \(last)") }
                }
            }
            XCTAssertGreaterThan(total, 50, code.rawValue)
            XCTAssertGreaterThanOrEqual(Double(agree) / Double(max(1, total)), 0.95, "\(code.rawValue): \(misses.joined(separator: "; "))")
            if !misses.isEmpty { print("[\(code.rawValue)] \(agree)/\(total) agree; differences: \(misses.joined(separator: "; "))") }
        }
    }
}
