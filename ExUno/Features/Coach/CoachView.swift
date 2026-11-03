import SwiftUI
import FoundationModels

/// An optional, entirely on-device practice session grounded in the bundled course.
struct CoachView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(GrammarCourses.self) private var courses
    @Environment(Vocabulary.self) private var vocabulary
    @State private var selectedUnit = ""
    @State private var mode: CoachMode = .free
    @State private var previousTopicID: String?
    @State private var activeTopic: ConversationTopic?
    @State private var scriptStep: Int?
    @State private var modelStarted = false
    @State private var didRestore = false
    @State private var message = ""
    @State private var transcript: [CoachMessage] = []
    @State private var working = false
    @State private var error: String?
    @State private var quiz: CoachQuiz?
    @State private var selectedAnswer: String?
    @State private var session: Any?
    @FocusState private var composing: Bool

    private var units: [GrammarUnit] {
        let selected = progress.settings.levels
        return courses.units.filter { selected.isEmpty || selected.contains($0.level) }
    }
    private var unit: GrammarUnit? { units.first { $0.id == selectedUnit } ?? units.first }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                if progress.language == .la {
                    unavailable("The coach is not available for Latin.")
                } else {
                    conversation
                }
            } else {
                unavailable("The coach requires iOS 26 or later and a device that supports Apple Intelligence. Your regular lessons remain available offline.")
            }
        }
        .pageBackground()
        .navigationTitle("Language coach")
        .navigationBarTitleDisplayMode(.inline)
         .onAppear {
            if selectedUnit.isEmpty { selectedUnit = units.first?.id ?? "" }
            if !didRestore { didRestore = true; restoreConversation() }
        }
        .onChange(of: message) { _, _ in saveConversation() }
    }

    private func unavailable(_ text: String) -> some View {
        Text(text).foregroundStyle(Theme.ink2).padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @available(iOS 26.0, *)
    private var conversation: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: mode == .free ? "bubble.left.and.bubble.right.fill" : "book.closed.fill").foregroundStyle(Theme.accent)
                if mode == .lesson {
                    Picker("Lesson", selection: $selectedUnit) {
                        ForEach(units) { unit in Text("\(unit.level) · \(unit.en)").tag(unit.id) }
                    }
                    .tint(Theme.ink)
                    .disabled(working)
                    .onChange(of: selectedUnit) { _, _ in reset() }
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Role play").font(.subheadline.weight(.semibold))
                        if let activeTopic { Text(activeTopic.situation).font(.caption).foregroundStyle(Theme.ink2) }
                    }
                }
                Spacer(minLength: 0)
                Menu {
                    Button("New role play", systemImage: "bubble.left.and.bubble.right") {
                        composing = false; mode = .free
                        Task { await startFreeConversation() }
                    }
                    if mode == .lesson && CoachHistory().load(progress.language) != nil {
                        Button("Resume conversation", systemImage: "arrow.uturn.backward") { restoreConversation() }
                    }
                    Button("New quiz", systemImage: "questionmark.circle") {
                        composing = false; mode = .lesson
                        Task { await startQuiz() }
                    }.disabled(units.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3).frame(width: 36, height: 36)
                }
                .disabled(working)
                .accessibilityLabel("Practice options")
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Theme.surface)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Text(SystemLanguageModel.default.isAvailable ? "Prepared role play · AI replies can make mistakes." : "Prepared role play is available. Free-form replies and generated quizzes need Apple Intelligence.")
                            .font(.caption).foregroundStyle(Theme.ink2).multilineTextAlignment(.center)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
                            .padding(.vertical, 8)

                        if transcript.isEmpty && quiz == nil && !working && error == nil {
                            VStack(spacing: 12) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.largeTitle).foregroundStyle(Theme.accent)
                                Text("Practice a little every day").font(.headline)
                                Text("Step into an everyday situation. Your coach will play the other person.")
                                    .font(.subheadline).foregroundStyle(Theme.ink2).multilineTextAlignment(.center)
                                Button("Start conversation") { mode = .free; Task { await startFreeConversation() } }
                                    .buttonStyle(.borderedProminent)
                                Button("Practice a quiz") { mode = .lesson; Task { await startQuiz() } }.buttonStyle(.bordered).disabled(units.isEmpty)
                            }.padding(.vertical, 40)
                        }

                        if let activeTopic {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("YOUR ROLE").font(.caption.bold()).foregroundStyle(Theme.accent)
                                Text(activeTopic.situation).font(.subheadline)
                                if let step = scriptStep, step < 2, let lines = activeTopic.lines(for: progress.language) {
                                    let suggestion = step == 0 ? lines.example : lines.secondExample
                                    Button { message = suggestion; composing = true } label: {
                                        Text("Try: \(suggestion)").font(.footnote)
                                    }.buttonStyle(.plain).foregroundStyle(Theme.accent)
                                    Text("Tap to use this reply, or write your own.").font(.caption).foregroundStyle(Theme.ink2)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
                                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14))
                        }
                        ForEach(transcript) { entry in
                            CoachBubble(message: entry)
                        }
                        if let quiz { quizCard(quiz) }
                        if working {
                            HStack {
                                ProgressView().padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
                                Spacer()
                            }.accessibilityLabel("Coach is responding")
                        }
                        if transcript.last?.isUser == true && scriptStep == nil && !working {
                            Button("Retry reply") { Task { await retryReply() } }.buttonStyle(.bordered)
                        }
                        if let error {
                            Text(error).font(.footnote).foregroundStyle(Theme.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if transcript.count >= 16 && quiz == nil {
                            Text("Start a new conversation to keep practicing.")
                                .font(.footnote).foregroundStyle(Theme.ink2)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(.horizontal, 16).padding(.bottom, 10)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: transcript.count) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
                .onChange(of: working) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
                .onChange(of: selectedAnswer) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
                .onChange(of: composing) { _, focused in if focused { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } } }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !transcript.isEmpty && quiz == nil {
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Message", text: $message, axis: .vertical)
                        .lineLimit(1...5).focused($composing)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 22))
                    Button { Task { await send() } } label: {
                        Image(systemName: "arrow.up").font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.onAccent).frame(width: 42, height: 42)
                            .background(Theme.accent, in: Circle())
                    }
                    .accessibilityLabel("Send message")
                    .disabled(working || transcript.count >= 16 || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(working || transcript.count >= 16 || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                }
                .padding(.horizontal, 12).padding(.vertical, 8).background(Theme.surface)
            }
        }
    }

    private func quizCard(_ quiz: CoachQuiz) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("QUIZ").font(.caption.bold()).foregroundStyle(Theme.accent)
                Text(quiz.question).font(.headline)
                ForEach(quiz.options, id: \.self) { option in
                    Button(option) { selectedAnswer = option }
                        .buttonStyle(.bordered).disabled(selectedAnswer != nil || working)
                }
                if let selectedAnswer {
                    Text(selectedAnswer == quiz.answer ? "Correct" : "Suggested answer: \(quiz.answer)").font(.headline)
                    Text(quiz.explanation).font(.subheadline)
                }
            }.padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
            Spacer(minLength: 30)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reset() {
        session = nil; transcript = []; quiz = nil; selectedAnswer = nil; error = nil; message = ""; activeTopic = nil; scriptStep = nil; modelStarted = false
    }

    @available(iOS 26.0, *)
    private func makeSession(_ unit: GrammarUnit) -> LanguageModelSession {
        let examples = unit.items.prefix(3).map { "\($0.sentence) — \($0.e)" }.joined(separator: "\n")
        return LanguageModelSession(model: .default, instructions: """
        You are a friendly language practice partner for an English speaker learning \(progress.language.englishName) at \(unit.level). Keep replies short and simple. Ask one question at a time. Use the lesson material below to guide the conversation. Do not invent grammar rules. If uncertain about a correction, say so.\nLesson: \(unit.en)\nRule: \(unit.note)\nExamples:\n\(examples)
        """)
    }

    private func saveConversation() {
        guard mode == .free, let topic = activeTopic, !transcript.isEmpty else { return }
        CoachHistory().save(SavedCoachConversation(topicID: topic.id, messages: transcript, scriptStep: scriptStep, draft: message), language: progress.language)
    }

    private func restoreConversation() {
        guard let saved = CoachHistory().load(progress.language),
              let topic = ConversationTopic.all.first(where: { $0.id == saved.topicID }),
              !saved.messages.isEmpty, topic.lines(for: progress.language) != nil else { return }
        reset()
        mode = .free; activeTopic = topic; previousTopicID = topic.id
        transcript = saved.messages; scriptStep = saved.scriptStep; message = saved.draft
    }

    @available(iOS 26.0, *)
    private func makeRoleSession(_ topic: ConversationTopic) -> LanguageModelSession? {
        guard let lines = topic.lines(for: progress.language) else { return nil }
        let selected = progress.settings.levels
        let words: [Entry]
        if let pack = vocabulary.current, pack.code == progress.language {
            words = Array(pack.entries.filter { entry in
                (selected.isEmpty ? pack.defaultLevels.contains(entry.level) : selected.contains(entry.level)) &&
                topic.keywords.contains { entry.translation.folded.contains($0.folded) }
            }.prefix(6))
        } else { words = [] }
        let reference = words.map { "\($0.wordWithArticle) — \($0.translation)" }.joined(separator: "; ")
        return LanguageModelSession(model: .default, instructions: """
        Role-play a simple everyday scene with a person learning \(progress.language.englishName). \(topic.situation) Your task: \(topic.direction)
        Stay in your role. Your opening line was: \(lines.opening)
        Respond naturally to the person's last message and move the situation forward one small step. Use one or two short, idiomatic sentences in \(progress.language.englishName); avoid mixing in English. Use simple familiar words. Ask at most one clear, concrete question that is easy to answer. If the person is confused or says they don't know, offer two simple choices or rephrase. Accept short answers and respond to their meaning. If they change direction, follow them. Never ask about grammar, lessons, homework, or which words they used. Do not correct them unless asked. Do not invent facts about the learner. Optional vocabulary: \(reference)
        """)
    }

    @available(iOS 26.0, *)
    private func startFreeConversation() async {
        reset()
        let topic = ConversationTopic.choose(excluding: previousTopicID)
        guard let lines = topic.lines(for: progress.language) else { return }
        previousTopicID = topic.id; activeTopic = topic
        scriptStep = 0
        transcript.append(CoachMessage(text: lines.opening, isUser: false))
        saveConversation()
    }

    @available(iOS 26.0, *)
    private func send() async {
        guard transcript.count < 16 else { return }
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        message = ""; transcript.append(CoachMessage(text: text, isUser: true)); error = nil
        if let topic = activeTopic, let lines = topic.lines(for: progress.language), let step = scriptStep, step < 2 {
            let expected = step == 0 ? lines.example : lines.secondExample
            if Self.matchesScript(text, expected) {
                transcript.append(CoachMessage(text: step == 0 ? lines.followUp : lines.closing, isUser: false))
                scriptStep = step + 1
                saveConversation()
                return
            }
        }
        guard SystemLanguageModel.default.isAvailable else {
            self.error = "Apple Intelligence is unavailable for a free-form reply. Use the suggested reply to continue the scene."
            saveConversation()
            return
        }
        scriptStep = nil
        saveConversation()
        await retryReply()
    }

    @available(iOS 26.0, *)
    private func retryReply() async {
        guard !working, let topic = activeTopic, let text = transcript.last?.text, transcript.last?.isUser == true else { return }
        guard SystemLanguageModel.default.isAvailable else { self.error = "Apple Intelligence is unavailable. Try again when it is ready."; return }
        guard let modelSession = (session as? LanguageModelSession) ?? makeRoleSession(topic) else { return }
        session = modelSession
        error = nil
        working = true
        defer { working = false }
        do {
            // The model has not seen the prepared messages. Give it the dialogue once when leaving the script.
            let prompt: String
            if !modelStarted {
                let history = transcript.map { "\($0.isUser ? "Learner" : "You"): \($0.text)" }.joined(separator: "\n")
                prompt = "Continue this role-play. Respond to the learner's last message:\n\(history)"
            } else {
                prompt = text
            }
            let response = try await modelSession.respond(to: prompt)
            modelStarted = true
            transcript.append(CoachMessage(text: response.content, isUser: false))
            saveConversation()
        } catch { self.error = "The coach couldn't reply. Try again. \(error.localizedDescription)" }

    }

    static func matchesScript(_ text: String, _ expected: String) -> Bool {
        func normalized(_ value: String) -> String {
            value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
                .map(String.init).joined()
        }
        return !normalized(expected).isEmpty && normalized(text) == normalized(expected)
    }

    @available(iOS 26.0, *)
    private func startQuiz() async {
        guard SystemLanguageModel.default.isAvailable else {
            reset(); self.error = "Generated quizzes need Apple Intelligence. Try a role play or a regular lesson."
            return
        }
        guard let unit, let item = unit.items.randomElement() else { return }
        reset(); working = true
        defer { working = false }
        let modelSession = makeSession(unit)
        do {
            let response = try await modelSession.respond(to: "Create one simple multiple-choice fill-in-the-blank question in \(progress.language.englishName) based on this course example: \(item.sentence) — \(item.e). Test the same answer: \(item.a). Give three distinct options including that exact answer. Use ___ for the blank. Explain briefly in English.", generating: GeneratedCoachQuiz.self)
            let result = response.content
            let candidate = CoachQuiz(question: result.question, options: result.options, answer: result.answer, explanation: result.explanation)
            guard candidate.hasValidStructure(expectedAnswer: item.a) else {
                self.error = "The generated quiz could not be checked. Please try again."
                return
            }
            quiz = candidate
        } catch { self.error = "The coach couldn't create a quiz. Try again or use the regular lesson. \(error.localizedDescription)" }
    }
}

@available(iOS 26.0, *)
@Generable
private struct GeneratedCoachQuiz {
    @Guide(description: "A sentence with one ___ blank") var question: String
    @Guide(description: "Three distinct answer choices") var options: [String]
    @Guide(description: "The correct answer, exactly as in the choices") var answer: String
    @Guide(description: "A brief explanation in English") var explanation: String
}

struct CoachQuiz {
    let question: String
    let options: [String]
    let answer: String
    let explanation: String

    func hasValidStructure(expectedAnswer: String) -> Bool {
        question.components(separatedBy: "___").count == 2 && !expectedAnswer.isEmpty &&
        answer == expectedAnswer && options.count == 3 && Set(options).count == 3 &&
        options.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } && options.contains(answer)
    }
}

private struct CoachBubble: View {
    let message: CoachMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 44) }
            Text(message.text)
                .textSelection(.enabled)
                .padding(.horizontal, 15).padding(.vertical, 10)
                .foregroundStyle(message.isUser ? Theme.onAccent : Theme.ink)
                .background(message.isUser ? Theme.accent : Theme.surface,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityLabel("\(message.isUser ? "You" : "Coach"): \(message.text)")
            if !message.isUser { Spacer(minLength: 44) }
        }.frame(maxWidth: .infinity)
    }
}

private enum CoachMode { case free, lesson }
