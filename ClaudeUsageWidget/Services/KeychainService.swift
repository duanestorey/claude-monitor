import Foundation

enum KeychainError: LocalizedError {
    case notFound
    case decodingFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Claude Code credentials not found in Keychain"
        case .decodingFailed(let detail):
            return "Failed to decode Keychain credentials: \(detail)"
        case .commandFailed(let detail):
            return "Keychain access failed: \(detail)"
        }
    }
}

final class KeychainService {
    static let shared = KeychainService()
    private init() {}

    func readCredentials() throws -> KeychainCredentials {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            if errorString.contains("could not be found") || process.terminationStatus == 44 {
                throw KeychainError.notFound
            }
            throw KeychainError.commandFailed(errorString.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty else {
            throw KeychainError.notFound
        }

        do {
            let credentials = try JSONDecoder().decode(KeychainCredentials.self, from: data)
            return credentials
        } catch {
            throw KeychainError.decodingFailed(error.localizedDescription)
        }
    }
}
