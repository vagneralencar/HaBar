import Foundation

public protocol HomeAssistantClientDelegate: AnyObject {
    @MainActor func clientDidAuthenticate(host: String)
    @MainActor func clientDidReceiveStateUpdate(_ stateObject: [String: Any])
}

public final class HomeAssistantClient {
    public weak var delegate: HomeAssistantClientDelegate?

    private let session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private var wsMessageId: Int = 1
    private static let areaTemplateQuery = "{% set ns = namespace(areas=[]) %}{% for a in areas() %}{% set ns.areas = ns.areas + [{\"id\": a, \"name\": area_name(a), \"entities\": area_entities(a)}] %}{% endfor %}{{ ns.areas | tojson }}"

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 4.0
        config.timeoutIntervalForResource = 8.0
        config.httpMaximumConnectionsPerHost = 4
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    public func fetchAreas(baseURL: String, token: String) async -> [[String: Any]]? {
        for candidateBase in candidateURLs(for: baseURL) {
            guard var request = buildAuthorizedRequest(
                baseURL: candidateBase,
                path: "/api/template",
                token: token,
                method: "POST"
            ) else { continue }

            request.httpBody = try? JSONSerialization.data(withJSONObject: ["template": Self.areaTemplateQuery])
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                    continue
                }
                if let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    return parsed
                }
            } catch {
                continue
            }
        }
        return nil
    }

    public func fetchStates(baseURL: String, token: String) async -> [[String: Any]]? {
        for candidateBase in candidateURLs(for: baseURL) {
            guard let request = buildAuthorizedRequest(
                baseURL: candidateBase,
                path: "/api/states",
                token: token,
                method: "GET"
            ) else { continue }

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                    continue
                }
                if let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    return parsed
                }
            } catch {
                continue
            }
        }
        return nil
    }

    public func callService(
        baseURL: String,
        token: String,
        domain: String,
        service: String,
        payload: [String: Any]
    ) async {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { return }

        for candidateBase in candidateURLs(for: baseURL) {
            guard var request = buildAuthorizedRequest(
                baseURL: candidateBase,
                path: "/api/services/\(domain)/\(service)",
                token: trimmedToken,
                method: "POST"
            ) else { continue }

            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            if let (_, response) = try? await session.data(for: request),
               let httpResp = response as? HTTPURLResponse,
               (200...299).contains(httpResp.statusCode) {
                return
            }
        }
    }

    public func connectWebSocket(baseURL: String, token: String) {
        disconnectWebSocket()

        let trimmedBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let wsBase = trimmedBase
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        guard let wsURL = URL(string: "\(wsBase)/api/websocket") else { return }

        let task = session.webSocketTask(with: wsURL)
        self.webSocketTask = task
        task.resume()

        listenForNextMessage(baseURL: baseURL, token: token)
    }

    public func disconnectWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Private DRY Helpers

    private func candidateURLs(for baseURL: String) -> [String] {
        let clean = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let fallback = KeychainHelper.fallbackURLString,
           !fallback.isEmpty,
           fallback != clean {
            return [clean, fallback.trimmingCharacters(in: CharacterSet(charactersIn: "/"))]
        }
        return [clean]
    }

    private func buildAuthorizedRequest(
        baseURL: String,
        path: String,
        token: String,
        method: String
    ) -> URLRequest? {
        let cleanBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(cleanBase)\(path)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func listenForNextMessage(baseURL: String, token: String) {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            guard case .success(let message) = result else { return }

            self.processWebSocketMessage(message, baseURL: baseURL, token: token)
            self.listenForNextMessage(baseURL: baseURL, token: token)
        }
    }

    private func processWebSocketMessage(
        _ message: URLSessionWebSocketTask.Message,
        baseURL: String,
        token: String
    ) {
        let rawData: Data?
        switch message {
        case .string(let text): rawData = text.data(using: .utf8)
        case .data(let data): rawData = data
        @unknown default: rawData = nil
        }

        guard let data = rawData,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "auth_required":
            sendJSON(["type": "auth", "access_token": token])
        case "auth_ok":
            wsMessageId += 1
            sendJSON([
                "id": wsMessageId,
                "type": "subscribe_events",
                "event_type": "state_changed"
            ])
            let host = URL(string: baseURL)?.host ?? "homeassistant.local"
            Task { @MainActor [weak self] in
                self?.delegate?.clientDidAuthenticate(host: host)
            }
        case "event":
            guard let event = json["event"] as? [String: Any],
                  let eventData = event["data"] as? [String: Any],
                  let newState = eventData["new_state"] as? [String: Any] else { return }
            Task { @MainActor [weak self] in
                self?.delegate?.clientDidReceiveStateUpdate(newState)
            }
        default:
            break
        }
    }

    private func sendJSON(_ dictionary: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { _ in }
    }
}
