import Foundation

// MARK: - CoachIA message model

struct CoachMessage: Identifiable {
    let id = UUID()
    let role: Role
    var text: String

    enum Role { case user, coach }
}

// MARK: - CoachIAService (SSE streaming)

final class CoachIAService {
    static let shared = CoachIAService()
    private init() {}

    /// Streams the AI coach response token by token.
    /// The returned AsyncStream yields partial text chunks as they arrive.
    /// On network loss it yields "[NETWORK_ERROR]" so the UI can react.
    func stream(userMessage: String, context: CoachContext? = nil) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                do {
                    var body: [String: Any] = ["message": userMessage]
                    if let ctx = context {
                        body["context"] = ctx.asDictionary
                    }
                    guard let data = try? JSONSerialization.data(withJSONObject: body) else {
                        continuation.finish()
                        return
                    }

                    var request = try APIClient.shared.buildRequest(
                        "ai/coach", method: "POST", body: data, authorized: true
                    )
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    // Use the configured session (15s/30s timeouts) instead of URLSession.shared
                    let (bytes, response) = try await APIClient.shared.bytesRequest(request)
                    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                        continuation.finish()
                        return
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let payload = String(line.dropFirst(6))
                            if payload == "[DONE]" { break }
                            if let chunk = parseSSEChunk(payload) {
                                continuation.yield(chunk)
                            }
                        }
                    }
                } catch let error as URLError
                    where [.networkConnectionLost, .notConnectedToInternet, .timedOut]
                        .contains(error.code) {
                    continuation.yield("[NETWORK_ERROR]")
                } catch { }
                continuation.finish()
            }
        }
    }

    // MARK: - SSE chunk parsing

    private func parseSSEChunk(_ payload: String) -> String? {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return payload }

        // OpenAI-style: choices[0].delta.content
        if let choices = json["choices"] as? [[String: Any]],
           let delta = choices.first?["delta"] as? [String: Any],
           let content = delta["content"] as? String {
            return content
        }
        // Simple flat: { "token": "..." }
        if let token = json["token"] as? String { return token }
        // Fallback: treat raw string
        return payload
    }
}

// MARK: - Coach context (recent activity summary sent alongside the prompt)

struct CoachContext {
    var streakDays: Int?
    var recentRunKm: Double?
    var recentGymSets: Int?
    var level: Int?

    var asDictionary: [String: Any] {
        var d: [String: Any] = [:]
        if let s = streakDays    { d["streak_days"]    = s }
        if let r = recentRunKm   { d["recent_run_km"]  = r }
        if let g = recentGymSets { d["recent_gym_sets"] = g }
        if let l = level          { d["level"]          = l }
        return d
    }
}
