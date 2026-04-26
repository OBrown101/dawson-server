import Foundation

final class CLIWrapper {
    static let shared = CLIWrapper()

    private let process = Process()
    private let inputPipe = Pipe()

    private init() {
        let cliPath = ("~/DAWSON/Sources/cli/cli.js" as NSString).expandingTildeInPath

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", cliPath]

        process.standardInput = inputPipe
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        do {
            try process.run()
        } catch {
            print("❌ Failed to start CLI renderer: \(error)")
        }
    }

    // Generic send
    func send(_ type: String, _ text: String = "", _ meta: [String: Any] = [:]) {
        var payload: [String: Any] = [
            "type": type,
            "text": text
        ]

        meta.forEach { payload[$0.key] = $0.value }

        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else { return }

        inputPipe.fileHandleForWriting.write((string + "\n").data(using: .utf8)!)
    }

    // MARK: - Convenience APIs

    func system(_ text: String) {
        send("system", text)
    }
    func user(_ text: String) {
        send("user", text)
    }

    func startProcessing(_ text: String = "Processing...") {
        send("start_processing", text)
    }
    
    func stopProcessing(_ text: String = "Processing...") {
        send("stop_processing", text)
    }

    func agent(_ text: String) {
        send("agent", text)
    }

    func streamThinking(_ chunk: String) {
        send("thinking_stream", chunk)
    }

    func streamContent(_ chunk: String) {
        send("content_stream", chunk)
    }

    func tool(_ text: String) {
        send("tool", text)
    }

    func header(_ text: String) {
        send("header", text)
    }

    func divider() {
        send("divider")
    }

    func error(_ text: String) {
        send("error", text)
    }
}
