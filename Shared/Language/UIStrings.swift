import Foundation

/// Learning-surface labels in the target language (settings and onboarding stay in English).
struct UIStrings {
    var today, cards, tools, words: String
    var morning, afternoon, evening: String
    var reviewToday: String
    var due: (Int) -> String
    var goalReached, readyForNew: String
    var cardsToday: (Int, Int) -> String
    var start, keepGoing: String
    var dailyChallenge, done, comeBack: String
    var correctCount: (Int, Int) -> String
    var check, next, finish, right: String
    var was: (String) -> String
    var showText: String
    var hard, show, again, good, easy, todayShort: String
    var days: (Int) -> String
    var showAnswer, howToSay, knew, didntKnow, realLife: String
    var write, listen: String
    var myDeck, phrases, levels, topics, all: String
    var entries: (Int) -> String
    var nothingHere, filter, session, toReview: String
    var streak, seen, solid: String

    static func `for`(_ code: LanguageCode) -> UIStrings {
        switch code {
        case .it:
            return UIStrings(today: "Oggi", cards: "Carte", tools: "Strumenti", words: "Parole",
                             morning: "Buongiorno", afternoon: "Buon pomeriggio", evening: "Buonasera",
                             reviewToday: "Ripasso di oggi", due: { "\($0) da ripassare" }, goalReached: "Obiettivo raggiunto", readyForNew: "Pronto per nuove parole",
                             cardsToday: { "\($0) di \($1) carte oggi" }, start: "Inizia", keepGoing: "Continua",
                             dailyChallenge: "Sfida del giorno", done: "Fatto", comeBack: "Torna domani.", correctCount: { "\($0) / \($1) corretti" },
                             check: "Controlla", next: "Avanti", finish: "Finisci", right: "Giusto!", was: { "Era \($0)" }, showText: "Mostra testo",
                             hard: "Difficile", show: "Mostra", again: "Di nuovo", good: "Bene", easy: "Facile", todayShort: "oggi",
                             days: { $0 == 1 ? "1 giorno" : "\($0) giorni" }, showAnswer: "Mostra la risposta", howToSay: "Come si dice?",
                             knew: "Lo sapevo", didntKnow: "Non lo sapevo", realLife: "vita reale", write: "Scrivi", listen: "Ascolta",
                             myDeck: "Il mio mazzo", phrases: "Frasi", levels: "Livelli", topics: "Temi", all: "Tutti", entries: { $0 == 1 ? "1 voce" : "\($0) voci" },
                             nothingHere: "Niente qui.", filter: "Filtra…", session: "Sessione", toReview: "Da rivedere",
                             streak: "giorni di fila", seen: "parole viste", solid: "in memoria")
        case .es, .esLatAm:
            return UIStrings(today: "Hoy", cards: "Tarjetas", tools: "Herramientas", words: "Palabras",
                             morning: "Buenos días", afternoon: "Buenas tardes", evening: "Buenas noches",
                             reviewToday: "Repaso de hoy", due: { "\($0) por repasar" }, goalReached: "Objetivo cumplido", readyForNew: "Listo para palabras nuevas",
                             cardsToday: { "\($0) de \($1) tarjetas hoy" }, start: "Empezar", keepGoing: "Seguir",
                             dailyChallenge: "Reto del día", done: "Hecho", comeBack: "Vuelve mañana.", correctCount: { "\($0) / \($1) correctas" },
                             check: "Comprobar", next: "Siguiente", finish: "Terminar", right: "¡Correcto!", was: { "Era \($0)" }, showText: "Ver texto",
                             hard: "Difícil", show: "Mostrar", again: "Otra vez", good: "Bien", easy: "Fácil", todayShort: "hoy",
                             days: { $0 == 1 ? "1 día" : "\($0) días" }, showAnswer: "Ver la respuesta", howToSay: "¿Cómo se dice?",
                             knew: "Lo sabía", didntKnow: "No lo sabía", realLife: "vida real", write: "Escribir", listen: "Escuchar",
                             myDeck: "Mi mazo", phrases: "Frases", levels: "Niveles", topics: "Temas", all: "Todos", entries: { $0 == 1 ? "1 entrada" : "\($0) entradas" },
                             nothingHere: "Nada aquí.", filter: "Filtrar…", session: "Sesión", toReview: "Para repasar",
                             streak: "días seguidos", seen: "palabras vistas", solid: "aprendidas")
        case .fr:
            return UIStrings(today: "Aujourd'hui", cards: "Cartes", tools: "Outils", words: "Mots",
                             morning: "Bonjour", afternoon: "Bon après-midi", evening: "Bonsoir",
                             reviewToday: "Révision du jour", due: { "\($0) à réviser" }, goalReached: "Objectif atteint", readyForNew: "Prêt pour de nouveaux mots",
                             cardsToday: { "\($0) sur \($1) cartes aujourd'hui" }, start: "Commencer", keepGoing: "Continuer",
                             dailyChallenge: "Défi du jour", done: "Terminé", comeBack: "Reviens demain.", correctCount: { "\($0) / \($1) justes" },
                             check: "Vérifier", next: "Suivant", finish: "Terminer", right: "Juste !", was: { "C'était \($0)" }, showText: "Voir le texte",
                             hard: "Difficile", show: "Montrer", again: "Encore", good: "Bien", easy: "Facile", todayShort: "aujourd'hui",
                             days: { $0 == 1 ? "1 jour" : "\($0) jours" }, showAnswer: "Voir la réponse", howToSay: "Comment on dit ?",
                             knew: "Je savais", didntKnow: "Je ne savais pas", realLife: "vie réelle", write: "Écrire", listen: "Écouter",
                             myDeck: "Mon paquet", phrases: "Expressions", levels: "Niveaux", topics: "Thèmes", all: "Tous", entries: { $0 == 1 ? "1 entrée" : "\($0) entrées" },
                             nothingHere: "Rien ici.", filter: "Filtrer…", session: "Séance", toReview: "À revoir",
                             streak: "jours d'affilée", seen: "mots vus", solid: "mémorisés")
        case .pt, .ptBR:
            return UIStrings(today: "Hoje", cards: "Cartões", tools: "Ferramentas", words: "Palavras",
                             morning: "Bom dia", afternoon: "Boa tarde", evening: "Boa noite",
                             reviewToday: "Revisão de hoje", due: { "\($0) para rever" }, goalReached: "Objetivo alcançado", readyForNew: "Pronto para palavras novas",
                             cardsToday: { "\($0) de \($1) cartões hoje" }, start: "Começar", keepGoing: "Continuar",
                             dailyChallenge: "Desafio do dia", done: "Concluído", comeBack: "Volta amanhã.", correctCount: { "\($0) / \($1) corretas" },
                             check: "Verificar", next: "Seguinte", finish: "Terminar", right: "Certo!", was: { "Era \($0)" }, showText: "Mostrar texto",
                             hard: "Difícil", show: "Mostrar", again: "Outra vez", good: "Bem", easy: "Fácil", todayShort: "hoje",
                             days: { $0 == 1 ? "1 dia" : "\($0) dias" }, showAnswer: "Mostrar a resposta", howToSay: "Como se diz?",
                             knew: "Sabia", didntKnow: "Não sabia", realLife: "vida real", write: "Escrever", listen: "Ouvir",
                             myDeck: "O meu baralho", phrases: "Frases", levels: "Níveis", topics: "Temas", all: "Todos", entries: { $0 == 1 ? "1 entrada" : "\($0) entradas" },
                             nothingHere: "Nada aqui.", filter: "Filtrar…", session: "Sessão", toReview: "Para rever",
                             streak: "dias seguidos", seen: "palavras vistas", solid: "memorizadas")
        case .la:
            return UIStrings(today: "Hodiē", cards: "Chartae", tools: "Īnstrūmenta", words: "Lexicon",
                             morning: "Salvē", afternoon: "Salvē", evening: "Salvē",
                             reviewToday: "Hodiē repetenda", due: { "\($0) repetenda" }, goalReached: "Fīnis attāctus", readyForNew: "Nova verba exspectant",
                             cardsToday: { "\($0) ex \($1) chartīs hodiē" }, start: "Incipe", keepGoing: "Perge",
                             dailyChallenge: "Certāmen cotīdiānum", done: "Factum", comeBack: "Crās redī.", correctCount: { "\($0) / \($1) recta" },
                             check: "Probā", next: "Porrō", finish: "Fīnī", right: "Rēctē!", was: { "Erat \($0)" }, showText: "Ostende",
                             hard: "Difficile", show: "Ostende", again: "Iterum", good: "Bene", easy: "Facile", todayShort: "hodiē",
                             days: { $0 == 1 ? "1 diēs" : "\($0) diēs" }, showAnswer: "Respōnsum ostende", howToSay: "Quōmodo dīcitur?",
                             knew: "Sciēbam", didntKnow: "Nesciēbam", realLife: "rēs vēra", write: "Scrībe", listen: "Audī",
                             myDeck: "Meae chartae", phrases: "Locūtiōnēs", levels: "Gradūs", topics: "Rēs", all: "Omnia", entries: { "\($0) verba" },
                             nothingHere: "Nihil hīc.", filter: "Quaere…", session: "Exercitātiō", toReview: "Repetenda",
                             streak: "diēs continuī", seen: "verba vīsa", solid: "memoriā tenta")
        }
    }

    func greeting(hour: Int) -> String { hour < 13 ? morning : hour < 18 ? afternoon : evening }
}
