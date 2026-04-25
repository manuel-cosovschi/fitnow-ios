import SwiftUI

// MARK: - CoachIA Chat View

struct CoachIAView: View {
    @State private var messages: [CoachMessage] = []
    @State private var inputText = ""
    @State private var isStreaming = false
    @State private var streamingId: UUID?
    @FocusState private var inputFocused: Bool

    private let quickPrompts = [
        "¿Qué debería comer hoy?",
        "Dame un plan de 30 min",
        "¿Cómo mejorar mi racha?",
        "Ejercicios para espalda",
        "¿Cuánto descanso necesito?",
    ]

    var body: some View {
        ZStack {
            Color.fnBg.ignoresSafeArea()

            VStack(spacing: 0) {
                messageList
                if messages.isEmpty { quickPromptsBar }
                inputBar
            }
        }
        .navigationTitle("Coach IA")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.fnBg, for: .navigationBar)
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        welcomeCard
                            .padding(.top, 24)
                    }
                    ForEach(messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: messages.last?.text) { _, _ in
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var welcomeCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.fnPurple.opacity(0.15)).frame(width: 72, height: 72)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.fnPurple)
            }
            Text("Hola, soy tu Coach IA")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.fnWhite)
            Text("Preguntame sobre nutrición, entrenamiento, recuperación, o lo que necesites para alcanzar tus objetivos.")
                .font(.system(size: 14))
                .foregroundColor(.fnSlate)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    private func messageBubble(_ msg: CoachMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if msg.role == .user { Spacer(minLength: 60) }

            if msg.role == .coach {
                ZStack {
                    Circle().fill(Color.fnPurple.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: "brain.head.profile").font(.system(size: 12)).foregroundColor(.fnPurple)
                }
            }

            VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 4) {
                Text(msg.text.isEmpty ? "…" : msg.text)
                    .font(.system(size: 14))
                    .foregroundColor(msg.role == .user ? .white : .fnWhite)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        msg.role == .user
                            ? Color.fnPurple
                            : Color.fnSurface,
                        in: RoundedRectangle(cornerRadius: 18)
                    )
                    .overlay(
                        Group {
                            if msg.role == .coach && msg.id == streamingId {
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.fnPurple.opacity(0.3), lineWidth: 1)
                            }
                        }
                    )
            }

            if msg.role == .coach { Spacer(minLength: 60) }
        }
    }

    // MARK: - Quick prompts

    private var quickPromptsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button { send(prompt) } label: {
                        Text(prompt)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.fnPurple)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.fnPurple.opacity(0.10), in: Capsule())
                            .overlay(Capsule().stroke(Color.fnPurple.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Escribí tu pregunta…", text: $inputText, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(.fnWhite)
                .lineLimit(1...4)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { if !inputText.isEmpty { send(inputText) } }

            Button {
                if !inputText.isEmpty { send(inputText) }
            } label: {
                Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(inputText.isEmpty && !isStreaming ? .fnSlate : .fnPurple)
            }
            .disabled(inputText.isEmpty && !isStreaming)
        }
        .padding(14)
        .background(Color.fnSurface)
        .overlay(Rectangle().fill(Color.fnBorder.opacity(0.5)).frame(height: 0.5), alignment: .top)
    }

    // MARK: - Send

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        messages.append(CoachMessage(role: .user, text: trimmed))
        inputText = ""
        inputFocused = false

        var coachMsg = CoachMessage(role: .coach, text: "")
        streamingId = coachMsg.id
        messages.append(coachMsg)
        isStreaming = true

        let context = buildContext()

        Task {
            for await chunk in CoachIAService.shared.stream(userMessage: trimmed, context: context) {
                if let idx = messages.firstIndex(where: { $0.id == coachMsg.id }) {
                    messages[idx].text += chunk
                }
            }
            streamingId = nil
            isStreaming = false
        }
    }

    private func buildContext() -> CoachContext {
        var ctx = CoachContext()
        if let entry = WidgetDataService.shared.read() {
            ctx.streakDays = entry.streakDays
            ctx.level = entry.level
        }
        return ctx
    }
}
