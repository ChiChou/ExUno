import Foundation

/// Rule-based conjugator: regular patterns plus a table of common irregular verbs.
/// Covers presente, passato prossimo, imperfetto and futuro semplice.
/// Italian conjugator (kept under its original name; `ItalianEngine` adapts it).
enum Conjugator {
    static let pronouns = ["io", "tu", "lui / lei", "noi", "voi", "loro"]
    private static let reflexivePronouns = ["mi", "ti", "si", "ci", "vi", "si"]

    struct Tense: Identifiable {
        let name: String
        let forms: [String]
        let note: String
        var id: String { name }
    }

    struct Result {
        let lemma: String
        let base: String
        let reflexive: Bool
        let ending: String
        let irregularPresent: Bool
        let tenses: [Tense]
        var kind: String {
            if reflexive { return "Verbo riflessivo" }
            if irregularPresent { return "Verbo irregolare" }
            return "Verbo regolare in -\(ending)"
        }
    }

    private static let iscVerbs: Set<String> = ["finire", "capire", "preferire", "pulire", "spedire", "costruire", "unire", "suggerire", "agire", "chiarire", "colpire", "definire", "digerire", "fornire", "garantire", "gestire", "guarire", "impedire", "inserire", "proibire", "punire", "reagire", "restituire", "riunire", "sostituire", "stabilire", "trasferire", "ubbidire", "obbedire", "favorire", "ferire", "fiorire", "arrossire", "approfondire", "condire", "contribuire", "distribuire", "diminuire", "esaurire", "esibire", "istruire", "sparire", "starnutire", "tradire"]

    private static let essereVerbs: Set<String> = ["essere", "andare", "venire", "stare", "rimanere", "uscire", "entrare", "arrivare", "partire", "tornare", "ritornare", "nascere", "morire", "diventare", "piacere", "succedere", "cadere", "salire", "scendere", "restare", "costare", "durare", "sembrare", "riuscire", "esistere", "accadere", "bastare", "mancare", "servire", "dispiacere", "crescere", "invecchiare", "ingrassare", "dimagrire", "guarire", "sparire", "apparire", "scomparire", "scappare", "fuggire", "emigrare"]

    private static let irregularPresent: [String: [String]] = [
        "essere": ["sono", "sei", "è", "siamo", "siete", "sono"], "avere": ["ho", "hai", "ha", "abbiamo", "avete", "hanno"],
        "andare": ["vado", "vai", "va", "andiamo", "andate", "vanno"], "fare": ["faccio", "fai", "fa", "facciamo", "fate", "fanno"],
        "stare": ["sto", "stai", "sta", "stiamo", "state", "stanno"], "dare": ["do", "dai", "dà", "diamo", "date", "danno"],
        "dire": ["dico", "dici", "dice", "diciamo", "dite", "dicono"], "venire": ["vengo", "vieni", "viene", "veniamo", "venite", "vengono"],
        "potere": ["posso", "puoi", "può", "possiamo", "potete", "possono"], "volere": ["voglio", "vuoi", "vuole", "vogliamo", "volete", "vogliono"],
        "dovere": ["devo", "devi", "deve", "dobbiamo", "dovete", "devono"], "sapere": ["so", "sai", "sa", "sappiamo", "sapete", "sanno"],
        "uscire": ["esco", "esci", "esce", "usciamo", "uscite", "escono"], "bere": ["bevo", "bevi", "beve", "beviamo", "bevete", "bevono"],
        "rimanere": ["rimango", "rimani", "rimane", "rimaniamo", "rimanete", "rimangono"], "tenere": ["tengo", "tieni", "tiene", "teniamo", "tenete", "tengono"],
        "piacere": ["piaccio", "piaci", "piace", "piacciamo", "piacete", "piacciono"], "scegliere": ["scelgo", "scegli", "sceglie", "scegliamo", "scegliete", "scelgono"],
        "morire": ["muoio", "muori", "muore", "moriamo", "morite", "muoiono"], "sedere": ["siedo", "siedi", "siede", "sediamo", "sedete", "siedono"],
        "salire": ["salgo", "sali", "sale", "saliamo", "salite", "salgono"], "porre": ["pongo", "poni", "pone", "poniamo", "ponete", "pongono"],
        "trarre": ["traggo", "trai", "trae", "traiamo", "traete", "traggono"], "tradurre": ["traduco", "traduci", "traduce", "traduciamo", "traducete", "traducono"],
        "produrre": ["produco", "produci", "produce", "produciamo", "producete", "producono"], "cuocere": ["cuocio", "cuoci", "cuoce", "cuociamo", "cuocete", "cuociono"],
        "apparire": ["appaio", "appari", "appare", "appariamo", "apparite", "appaiono"], "riuscire": ["riesco", "riesci", "riesce", "riusciamo", "riuscite", "riescono"],
        "togliere": ["tolgo", "togli", "toglie", "togliamo", "togliete", "tolgono"], "cogliere": ["colgo", "cogli", "coglie", "cogliamo", "cogliete", "colgono"],
        "valere": ["valgo", "vali", "vale", "valiamo", "valete", "valgono"], "udire": ["odo", "odi", "ode", "udiamo", "udite", "odono"],
        "spegnere": ["spengo", "spegni", "spegne", "spegniamo", "spegnete", "spengono"], "raccogliere": ["raccolgo", "raccogli", "raccoglie", "raccogliamo", "raccogliete", "raccolgono"]
    ]

    private static let irregularParticiples: [String: String] = [
        "essere": "stato", "fare": "fatto", "dire": "detto", "venire": "venuto", "bere": "bevuto", "rimanere": "rimasto", "prendere": "preso", "mettere": "messo", "vedere": "visto", "leggere": "letto", "scrivere": "scritto", "aprire": "aperto", "chiudere": "chiuso", "scegliere": "scelto", "vivere": "vissuto", "morire": "morto", "nascere": "nato", "rispondere": "risposto", "chiedere": "chiesto", "perdere": "perso", "correre": "corso", "decidere": "deciso", "offrire": "offerto", "conoscere": "conosciuto", "rompere": "rotto", "vincere": "vinto", "piacere": "piaciuto", "succedere": "successo", "accendere": "acceso", "spegnere": "spento", "spendere": "speso", "scendere": "sceso", "ridere": "riso", "piangere": "pianto", "dipingere": "dipinto", "spingere": "spinto", "cuocere": "cotto", "tradurre": "tradotto", "produrre": "prodotto", "porre": "posto", "trarre": "tratto", "togliere": "tolto", "cogliere": "colto", "raccogliere": "raccolto", "discutere": "discusso", "esprimere": "espresso", "muovere": "mosso", "nascondere": "nascosto", "uccidere": "ucciso", "dividere": "diviso", "convincere": "convinto", "dirigere": "diretto", "proteggere": "protetto", "raggiungere": "raggiunto", "giungere": "giunto", "stringere": "stretto", "coprire": "coperto", "soffrire": "sofferto", "scoprire": "scoperto", "sorridere": "sorriso", "rimettere": "rimesso", "promettere": "promesso", "permettere": "permesso", "ammettere": "ammesso", "riprendere": "ripreso", "comprendere": "compreso", "sorprendere": "sorpreso", "apparire": "apparso", "scomparire": "scomparso", "valere": "valso", "sedere": "seduto", "udire": "udito", "avere": "avuto", "esistere": "esistito", "crescere": "cresciuto", "cadere": "caduto", "tenere": "tenuto", "sapere": "saputo", "volere": "voluto", "potere": "potuto", "dovere": "dovuto", "trasmettere": "trasmesso", "distruggere": "distrutto", "correggere": "corretto", "eleggere": "eletto", "concludere": "concluso", "includere": "incluso", "escludere": "escluso", "mordere": "morso", "assumere": "assunto"
    ]

    private static let irregularFutureStems: [String: String] = [
        "essere": "sar", "avere": "avr", "andare": "andr", "fare": "far", "stare": "star", "dare": "dar", "dire": "dir", "venire": "verr", "potere": "potr", "volere": "vorr", "dovere": "dovr", "sapere": "sapr", "vedere": "vedr", "vivere": "vivr", "bere": "berr", "rimanere": "rimarr", "tenere": "terr", "cadere": "cadr", "morire": "morr", "porre": "porr", "trarre": "trarr", "tradurre": "tradurr", "produrre": "produrr", "valere": "varr"
    ]

    private static let irregularImperfect: [String: [String]] = [
        "essere": ["ero", "eri", "era", "eravamo", "eravate", "erano"], "fare": ["facevo", "facevi", "faceva", "facevamo", "facevate", "facevano"],
        "dire": ["dicevo", "dicevi", "diceva", "dicevamo", "dicevate", "dicevano"], "bere": ["bevevo", "bevevi", "beveva", "bevevamo", "bevevate", "bevevano"],
        "porre": ["ponevo", "ponevi", "poneva", "ponevamo", "ponevate", "ponevano"], "trarre": ["traevo", "traevi", "traeva", "traevamo", "traevate", "traevano"],
        "tradurre": ["traducevo", "traducevi", "traduceva", "traducevamo", "traducevate", "traducevano"], "produrre": ["producevo", "producevi", "produceva", "producevamo", "producevate", "producevano"]
    ]

    private struct Analysis {
        let lemma: String
        let base: String
        let reflexive: Bool
        let ending: String   // are / ere / ire / rre
        let stem: String
    }

    private static func analyze(_ input: String) -> Analysis? {
        let lemma = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard lemma.count >= 4 else { return nil }
        var reflexive = false
        var base = lemma
        if lemma.hasSuffix("arsi") || lemma.hasSuffix("ersi") || lemma.hasSuffix("irsi") {
            reflexive = true
            base = String(lemma.dropLast(2)) + "e"
        }
        let ending: String
        if base.hasSuffix("rre") { ending = "rre" }
        else {
            let e = String(base.suffix(3))
            guard ["are", "ere", "ire"].contains(e) else { return nil }
            ending = e
        }
        return Analysis(lemma: lemma, base: base, reflexive: reflexive, ending: ending, stem: String(base.dropLast(3)))
    }

    private static func present(_ a: Analysis) -> (forms: [String], irregular: Bool, isc: Bool)? {
        if let f = irregularPresent[a.base] { return (f, true, false) }
        if a.ending == "rre" { return nil }
        let endings: [String]
        switch a.ending {
        case "are": endings = ["o", "i", "a", "iamo", "ate", "ano"]
        case "ere": endings = ["o", "i", "e", "iamo", "ete", "ono"]
        default: endings = ["o", "i", "e", "iamo", "ite", "ono"]
        }
        let isc = iscVerbs.contains(a.base)
        var forms: [String] = []
        for (i, e) in endings.enumerated() {
            var st = a.stem
            let startsWithI = e.hasPrefix("i")
            if a.ending == "are" && (st.hasSuffix("c") || st.hasSuffix("g")) && startsWithI { st += "h" }          // cercare → cerchi
            if a.ending == "are" && (st.hasSuffix("ci") || st.hasSuffix("gi")) && startsWithI { st.removeLast() }  // mangiare → mangi
            if a.ending == "ire" && isc && i != 3 && i != 4 { st += "isc" }
            if st.hasSuffix("i") && startsWithI && a.ending != "ire" { st.removeLast() }                            // studiare → studi
            forms.append(st + e)
        }
        return (forms, false, isc)
    }

    private static func participle(_ a: Analysis) -> (form: String, irregular: Bool)? {
        if let p = irregularParticiples[a.base] { return (p, true) }
        if a.ending == "rre" { return nil }
        let suffix = a.ending == "are" ? "ato" : a.ending == "ere" ? "uto" : "ito"
        return (a.stem + suffix, false)
    }

    private static func imperfect(_ a: Analysis) -> [String]? {
        if let f = irregularImperfect[a.base] { return f }
        if a.ending == "rre" { return nil }
        let v = a.ending == "are" ? "a" : a.ending == "ere" ? "e" : "i"
        return ["vo", "vi", "va", "vamo", "vate", "vano"].map { a.stem + v + $0 }
    }

    private static func future(_ a: Analysis) -> [String]? {
        var fs = irregularFutureStems[a.base]
        if fs == nil {
            if a.ending == "rre" { return nil }
            if a.ending == "are" {
                var s = a.stem
                if s.hasSuffix("ci") || s.hasSuffix("gi") { s.removeLast(); fs = s + "er" }
                else if s.hasSuffix("c") || s.hasSuffix("g") { fs = s + "her" }
                else { fs = s + "er" }
            } else {
                fs = a.stem + (a.ending == "ere" ? "er" : "ir")
            }
        }
        guard let stem = fs else { return nil }
        return ["ò", "ai", "à", "emo", "ete", "anno"].map { stem + $0 }
    }

    static func conjugate(_ input: String) -> Result? {
        guard let a = analyze(input) else { return nil }
        func wrap(_ forms: [String]) -> [String] {
            a.reflexive ? forms.enumerated().map { "\(reflexivePronouns[$0.offset]) \($0.element)" } : forms
        }
        var tenses: [Tense] = []
        let pr = present(a)
        if let pr {
            tenses.append(Tense(name: "Presente", forms: wrap(pr.forms), note: pr.irregular ? "irregular" : pr.isc ? "-isc- pattern" : "regular"))
        }
        if let pp = participle(a) {
            let usesEssere = a.reflexive || essereVerbs.contains(a.base)
            let aux = usesEssere ? irregularPresent["essere"]! : irregularPresent["avere"]!
            let part = pp.form
            let forms: [String] = aux.enumerated().map { i, auxForm in
                if usesEssere {
                    let plural = String(part.dropLast()) + "i"
                    if i == 2 { return "\(auxForm) \(part)/\(String(part.dropLast()))a" }
                    return "\(auxForm) \(i >= 3 ? plural : part)"
                }
                return "\(auxForm) \(part)"
            }
            tenses.append(Tense(name: "Passato prossimo", forms: wrap(forms), note: "\(usesEssere ? "essere" : "avere") + \(part)\(pp.irregular ? " (irregular participle)" : "")"))
        }
        if let im = imperfect(a) {
            tenses.append(Tense(name: "Imperfetto", forms: wrap(im), note: irregularImperfect[a.base] != nil ? "irregular" : "regular"))
        }
        if let fu = future(a) {
            tenses.append(Tense(name: "Futuro semplice", forms: wrap(fu), note: irregularFutureStems[a.base] != nil ? "irregular stem" : "regular"))
        }
        guard !tenses.isEmpty else { return nil }
        return Result(lemma: a.lemma, base: a.base, reflexive: a.reflexive, ending: a.ending, irregularPresent: pr?.irregular ?? false, tenses: tenses)
    }
}
