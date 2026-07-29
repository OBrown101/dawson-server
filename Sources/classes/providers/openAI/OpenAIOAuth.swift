//
//  OpenAIOAuth.swift
//  DAWSON
//
//  Created by Ethan Brown on 7/25/26.
//

import Foundation
import Network
import CryptoKit

private actor RefreshCoordinator {
    private var inFlight: Task<OpenAIOAuth.OAuthTokens, Error>?

    func refresh(_ operation: @Sendable @escaping () async throws -> OpenAIOAuth.OAuthTokens) async throws -> OpenAIOAuth.OAuthTokens {
        if let inFlight {
            // A refresh is already running; ride along instead of double-refreshing.
            return try await inFlight.value
        }
        let task = Task { try await operation() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}

final class OpenAIOAuth: @unchecked Sendable {
    static let shared = OpenAIOAuth()
    
    private let refreshCoordinator = RefreshCoordinator()

    static let clientId = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let authorizeURL = "https://auth.openai.com/oauth/authorize"
    static let tokenURL = "https://auth.openai.com/oauth/token"
    static let redirectURI = "http://localhost:1455/auth/callback"
    static let callbackPort: UInt16 = 1455

    static let codexEndpointURL = "https://chatgpt.com/backend-api/codex/responses"
    private let tokenFile = DAWSON.security.appendingPathComponent("openai_oauth.json")

    private(set) var tokens: OAuthTokens?

    var isActive: Bool {
        (tokens != nil)
    }
    
    var isRouting: Bool {
        return (isActive && (ProviderClient.ProviderType.openai.apiKey?.isEmpty ?? true))
    }

    init() {
        tokens = try? JSONDecoder().decode(OAuthTokens.self, from: Data(contentsOf: tokenFile))
    }

    func login() async throws {
        // Kicks off the full browser login. Returns once tokens are stored (or throws).
        
        let verifier = Self.randomURLSafe(64)
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = Self.randomURLSafe(32)

        guard var components = URLComponents(string: Self.authorizeURL) else {
            throw NSError(domain: "OpenAIOAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid authorize URL"])
        }
        components.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: Self.clientId),
            .init(name: "redirect_uri", value: Self.redirectURI),
            .init(name: "scope", value: "openid profile email offline_access"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            // Extra params Codex CLI sends:
            .init(name: "id_token_add_organizations", value: "true"),
            .init(name: "codex_cli_simplified_flow", value: "true"),
            .init(name: "originator", value: "codex_cli_rs")
        ]

        guard let authURL = components.url else {
            throw NSError(domain: "OpenAIOAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid authorize URL"])
        }

        async let code = waitForCallback(expectedState: state)  // Start the callback listener BEFORE opening the browser.

        openBrowser(authURL)

        let authCode = try await code
        let json = try await postToken(form: [
            "grant_type": "authorization_code",
            "code": authCode,
            "redirect_uri": Self.redirectURI,
            "client_id": Self.clientId,
            "code_verifier": verifier
        ])
        try store(tokenJSON: json)
        print("OpenAI OAuth login complete for account \(tokens?.accountId ?? "?")")
    }

    func validAccessToken() async throws -> OAuthTokens {
        guard let current = tokens else {
            throw NSError(domain: "OpenAIOAuth", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Not logged in with ChatGPT"])
        }
        guard current.isNearExpiry else { return current }

        return try await refreshCoordinator.refresh { [weak self] in
            guard let self else {
                throw NSError(domain: "OpenAIOAuth", code: -3,
                              userInfo: [NSLocalizedDescriptionKey: "Token refresh failed"])
            }
            // Re-check inside the coordinator: a caller that queued behind a
            // completed refresh should use the fresh token, not refresh again.
            if let latest = self.tokens, (!latest.isNearExpiry) {
                return latest
            }
            guard let stale = self.tokens else {
                throw NSError(domain: "OpenAIOAuth", code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "Not logged in with ChatGPT"])
            }
            let json = try await self.postToken(form: [
                "grant_type": "refresh_token",
                "refresh_token": stale.refreshToken,
                "client_id": Self.clientId,
                "scope": "openid profile email"
            ])
            try self.store(tokenJSON: json, previousRefreshToken: stale.refreshToken)
            guard let refreshed = self.tokens else {
                throw NSError(domain: "OpenAIOAuth", code: -3,
                              userInfo: [NSLocalizedDescriptionKey: "Token refresh failed"])
            }
            return refreshed
        }
    }

    func logout() {
        tokens = nil
        try? FileManager.default.removeItem(at: tokenFile)
    }

    private func postToken(form: [String: String]) async throws -> [String: Any] {
        guard let url = URL(string: Self.tokenURL) else {
            throw NSError(domain: "OpenAIOAuth", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid token URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "OpenAIOAuth", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Token endpoint HTTP \(httpResponse.statusCode): \(body)"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "OpenAIOAuth", code: -5,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid token response"])
        }
        return json
    }

    private func store(tokenJSON json: [String: Any], previousRefreshToken: String? = nil) throws {
        guard let accessToken = json["access_token"] as? String else {
            throw NSError(domain: "OpenAIOAuth", code: -6,
                          userInfo: [NSLocalizedDescriptionKey: "No access_token in response"])
        }
        // Refresh responses may omit a new refresh_token; keep the old one.
        let refreshToken = (json["refresh_token"] as? String) ?? previousRefreshToken ?? ""
        let expiresIn = (json["expires_in"] as? Int) ?? 3600
        let accountId = Self.extractAccountId(fromJWT: accessToken) ?? tokens?.accountId ?? ""

        tokens = OAuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: json["id_token"] as? String,
            accountId: accountId,
            expiresAt: Date.now.epochMillis + Int64(expiresIn) * 1000
        )
        let data = try JSONEncoder().encode(tokens)
        try data.write(to: tokenFile, options: .atomic)
        // NOTE: consider chmod 600 / Keychain — this file grants access to the user's subscription.
    }

    static func extractAccountId(fromJWT jwt: String) -> String? {
        // Pulls chatgpt_account_id out of the access token's "https://api.openai.com/auth" claim
        
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while ((payload.count % 4) != 0) { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let auth = json["https://api.openai.com/auth"] as? [String: Any] else { return nil }
        return auth["chatgpt_account_id"] as? String
    }

    private func waitForCallback(expectedState: String) async throws -> String {
        // Localhost callback server (port 1455, fixed by OpenAI's registered redirect URI)
        
        guard let port = NWEndpoint.Port(rawValue: Self.callbackPort) else {
            throw NSError(domain: "OpenAIOAuth", code: -7,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid callback port"])
        }
        let listener = try NWListener(using: .tcp, on: port)

        let stream = AsyncThrowingStream<String, Error> { @Sendable continuation in
            listener.newConnectionHandler = { connection in
                connection.start(queue: .global())
                connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { data, _, _, _ in
                    defer { connection.cancel() }

                    guard let data,
                          let request = String(data: data, encoding: .utf8),
                          let requestLine = request.split(separator: "\r\n").first,
                          (requestLine.contains("GET /auth/callback")) else {
                        Self.respond(connection, body: "Not found", status: "404 Not Found")
                        return
                    }

                    let lineParts = requestLine.split(separator: " ")
                    guard (lineParts.count >= 2),
                          let components = URLComponents(string: "http://localhost\(lineParts[1])") else {
                        Self.respond(connection, body: "Bad request", status: "400 Bad Request")
                        return
                    }

                    let query = components.queryItems ?? []
                    let code = query.first(where: { $0.name == "code" })?.value
                    let state = query.first(where: { $0.name == "state" })?.value

                    if let code,
                       (state == expectedState) {
                        Self.respond(connection, body: "<html><body><h2>DAWSON is connected to ChatGPT.</h2>You can close this tab.</body></html>")
                        continuation.yield(code)
                        continuation.finish()
                    } else {
                        Self.respond(connection, body: "Auth failed (state mismatch or missing code).", status: "400 Bad Request")
                        continuation.finish(throwing: NSError(
                            domain: "OpenAIOAuth", code: -8,
                            userInfo: [NSLocalizedDescriptionKey: "OAuth callback state mismatch or missing code"]))
                    }
                }
            }

            continuation.onTermination = { _ in
                listener.cancel()
            }

            listener.start(queue: .global())
        }

        for try await code in stream {
            return code
        }

        throw NSError(domain: "OpenAIOAuth", code: -9,
                      userInfo: [NSLocalizedDescriptionKey: "OAuth callback ended without a code"])
    }

    private static func respond(_ connection: NWConnection, body: String, status: String = "200 OK") {
        let response = "HTTP/1.1 \(status)\r\nContent-Type: text/html\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in })
    }

    private func openBrowser(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
        try? process.run()
        print("If the browser didn't open, visit: \(url.absoluteString)")
    }
}

extension OpenAIOAuth {
    
    private static func randomURLSafe(_ length: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension OpenAIOAuth {
    
    struct OAuthTokens: Codable {
        var accessToken: String
        var refreshToken: String
        var idToken: String?
        var accountId: String
        var expiresAt: Int64

        var isNearExpiry: Bool {
            // Refresh if within 5 minutes of expiry
            return (Date.now.epochMillis > (expiresAt - 5 * 60 * 1000))
        }
    }
}

extension OpenAIOAuth {
    
    static let codexInstructions = #"""
    You are Codex, based on GPT-5. You are running as a coding agent in the Codex CLI on a user's computer.

    ## General

    - When searching for text or files, prefer using `rg` or `rg --files` respectively because `rg` is much faster than alternatives like `grep`. (If the `rg` command is not found, then use alternatives.)

    ## Editing constraints

    - Default to ASCII when editing or creating files. Only introduce non-ASCII or other Unicode characters when there is a clear justification and the file already uses them.
    - Add succinct code comments that explain what is going on if code is not self-explanatory. You should not add comments like "Assigns the value to the variable", but a brief comment might be useful ahead of a complex code block that the user would otherwise have to spend time parsing out. Usage of these comments should be rare.
    - Try to use apply_patch for single file edits, but it is fine to explore other options to make the edit if it does not work well. Do not use apply_patch for changes that are auto-generated (i.e. generating package.json or running a lint or format command like gofmt) or when scripting is more efficient (such as search and replacing a string across a codebase).
    - You may be in a dirty git worktree.
        * NEVER revert existing changes you did not make unless explicitly requested, since these changes were made by the user.
        * If asked to make a commit or code edits and there are unrelated changes to your work or changes that you didn't make in those files, don't revert those changes.
        * If the changes are in files you've touched recently, you should read carefully and understand how you can work with the changes rather than reverting them.
        * If the changes are in unrelated files, just ignore them and don't revert them.
    - Do not amend a commit unless explicitly requested to do so.
    - While you are working, you might notice unexpected changes that you didn't make. If this happens, STOP IMMEDIATELY and ask the user how they would like to proceed.
    - **NEVER** use destructive commands like `git reset --hard` or `git checkout --` unless specifically requested or approved by the user.

    ## Plan tool

    When using the planning tool:
    - Skip using the planning tool for straightforward tasks (roughly the easiest 25%).
    - Do not make single-step plans.
    - When you made a plan, update it after having performed one of the sub-tasks that you shared on the plan.

    ## Special user requests

    - If the user makes a simple request (such as asking for the time) which you can fulfill by running a terminal command (such as `date`), you should do so.
    - If the user asks for a "review", default to a code review mindset: prioritise identifying bugs, risks, behavioural regressions, and missing tests. Findings must be the primary focus of the response - keep summaries or overviews brief and only after enumerating the issues. Present findings first (ordered by severity with file/line references), follow with open questions or assumptions, and offer a change-summary only as a secondary detail. If no findings are discovered, state that explicitly and mention any residual risks or testing gaps.

    ## Presenting your work and final message

    You are producing plain text that will later be styled by the CLI. Follow these rules exactly. Formatting should make results easy to scan, but not feel mechanical. Use judgment to decide how much structure adds value.

    - Default: be very concise; friendly coding teammate tone.
    - Ask only when needed; suggest ideas; mirror the user's style.
    - For substantial work, summarize clearly; follow final‑answer formatting.
    - Skip heavy formatting for simple confirmations.
    - Don't dump large files you've written; reference paths only.
    - No "save/copy this file" - User is on the same machine.
    - Offer logical next steps (tests, commits, build) briefly; add verify steps if you couldn't do something.
    - For code changes:
      * Lead with a quick explanation of the change, and then give more details on the context covering where and why a change was made. Do not start this explanation with "summary", just jump right in.
      * If there are natural next steps the user may want to take, suggest them at the end of your response. Do not make suggestions if there are no natural next steps.
      * When suggesting multiple options, use numeric lists for the suggestions so the user can quickly respond with a single number.
    - The user does not command execution outputs. When asked to show the output of a command (e.g. `git show`), relay the important details in your answer or summarize the key lines so the user understands the result.

    ### Final answer structure and style guidelines

    - Plain text; CLI handles styling. Use structure only when it helps scanability.
    - Headers: optional; short Title Case (1-3 words) wrapped in **…**; no blank line before the first bullet; add only if they truly help.
    - Bullets: use - ; merge related points; keep to one line when possible; 4–6 per list ordered by importance; keep phrasing consistent.
    - Monospace: backticks for commands/paths/env vars/code ids and inline examples; use for literal keyword bullets; never combine with **.
    - Code samples or multi-line snippets should be wrapped in fenced code blocks; include an info string as often as possible.
    - Structure: group related bullets; order sections general → specific → supporting; for subsections, start with a bolded keyword bullet, then items; match complexity to the task.
    - Tone: collaborative, concise, factual; present tense, active voice; self‑contained; no "above/below"; parallel wording.
    - Don'ts: no nested bullets/hierarchies; no ANSI codes; don't cram unrelated keywords; keep keyword lists short—wrap/reformat if long; avoid naming formatting styles in answers.
    - Adaptation: code explanations → precise, structured with code refs; simple tasks → lead with outcome; big changes → logical walkthrough + rationale + next actions; casual one-offs → plain sentences, no headers/bullets.
    - File References: When referencing files in your response, make sure to include the relevant start line and always follow the below rules:
      * Use inline code to make file paths clickable.
      * Each reference should have a stand alone path. Even if it's the same file.
      * Accepted: absolute, workspace‑relative, a/ or b/ diff prefixes, or bare filename/suffix.
      * Line/column (1‑based, optional): :line[:column] or #Lline[Ccolumn] (column defaults to 1).
      * Do not use URIs like file://, vscode://, or https://.
      * Do not provide range of lines
      * Examples: src/app.ts, src/app.ts:42, b/server/index.js#L10, C:\repo\project\main.rs:12:5
    """#
}
