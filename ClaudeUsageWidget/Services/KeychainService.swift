import Foundation

enum KeychainError: LocalizedError {
    case notFound
    case decodingFailed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Claude Code credentials not found in Keychain or credentials file"
        case .decodingFailed(let detail):
            return "Failed to decode credentials: \(detail)"
        case .commandFailed(let detail):
            return "Credential access failed: \(detail)"
        }
    }
}

final class KeychainService {
    static let shared = KeychainService()
    private init() {}

    func readCredentials() async throws -> KeychainCredentials {
        // Try ~/.claude/.credentials.json first (avoids keychain -w truncation bugs),
        // fall back to keychain if the file doesn't exist
        if let fileCreds = readFromCredentialsFile() {
            return fileCreds
        }
        return try await readFromKeychain()
    }

    // MARK: - Keychain

    private func readFromKeychain() async throws -> KeychainCredentials {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
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
                            continuation.resume(throwing: KeychainError.notFound)
                            return
                        }
                        continuation.resume(throwing: KeychainError.commandFailed(errorString.trimmingCharacters(in: .whitespacesAndNewlines)))
                        return
                    }

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    guard !data.isEmpty else {
                        continuation.resume(throwing: KeychainError.notFound)
                        return
                    }

                    let credentials = try JSONDecoder().decode(KeychainCredentials.self, from: data)
                    continuation.resume(returning: credentials)
                } catch let error as KeychainError {
                    continuation.resume(throwing: error)
                } catch let error as DecodingError {
                    continuation.resume(throwing: KeychainError.decodingFailed(error.localizedDescription))
                } catch {
                    continuation.resume(throwing: KeychainError.commandFailed(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - Credentials file fallback

    private func readFromCredentialsFile() -> KeychainCredentials? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let credentialsPath = home.appendingPathComponent(".claude/.credentials.json")

        guard let data = try? Data(contentsOf: credentialsPath),
              let credentials = try? JSONDecoder().decode(KeychainCredentials.self, from: data) else {
            return nil
        }
        return credentials
    }
}
