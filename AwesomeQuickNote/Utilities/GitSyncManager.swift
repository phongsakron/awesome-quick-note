import Foundation
import Observation

enum GitSyncStatus: Equatable {
    case disabled
    case notARepo
    case idle
    case syncing
    case error(String)
    case noRemote
}

@Observable
@MainActor
final class GitSyncManager {
    var status: GitSyncStatus = .disabled
    var lastSyncDate: Date?

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "gitSyncEnabled")
            if isEnabled {
                if let url = vaultURL {
                    configure(vaultURL: url)
                }
            } else {
                status = .disabled
                cancelTimers()
            }
        }
    }

    private var vaultURL: URL?
    private var hasRemote = false
    private var debounceTask: Task<Void, Never>?
    private var periodicPullTask: Task<Void, Never>?

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: "gitSyncEnabled")
    }

    // MARK: - Configuration

    func configure(vaultURL: URL?) {
        cancelTimers()
        self.vaultURL = vaultURL

        guard isEnabled, let vaultURL else {
            if isEnabled { status = .notARepo }
            return
        }

        Task {
            let isRepo = await checkIsGitRepo(at: vaultURL)
            guard isRepo else {
                status = .notARepo
                return
            }

            hasRemote = await checkHasRemote(at: vaultURL)
            if !hasRemote {
                status = .noRemote
            } else {
                status = .idle
                await pullFromRemote(at: vaultURL)
            }

            startPeriodicPull()
        }
    }

    // MARK: - Notifications

    func notifyFileChanged() {
        guard isEnabled, status != .disabled, status != .notARepo else { return }

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await runSyncCycle()
        }
    }

    func manualSync() {
        guard isEnabled, let vaultURL else { return }

        Task {
            let isRepo = await checkIsGitRepo(at: vaultURL)
            guard isRepo else {
                status = .notARepo
                return
            }
            hasRemote = await checkHasRemote(at: vaultURL)
            await runSyncCycle()
        }
    }

    // MARK: - Sync Cycle

    private func runSyncCycle() async {
        guard let vaultURL else { return }

        status = .syncing

        do {
            // Pull with rebase if remote exists
            if hasRemote {
                try await runGit(["pull", "--rebase", "--autostash"], at: vaultURL)
            }

            // Stage all changes
            try await runGit(["add", "-A"], at: vaultURL)

            // Check if there's anything to commit
            let hasStagedChanges: Bool
            do {
                try await runGit(["diff", "--cached", "--quiet"], at: vaultURL)
                hasStagedChanges = false
            } catch {
                hasStagedChanges = true
            }

            if hasStagedChanges {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let timestamp = formatter.string(from: Date())
                try await runGit(["commit", "-m", "Auto-sync: \(timestamp)"], at: vaultURL)
            }

            // Push if remote exists
            if hasRemote {
                try await runGit(["push"], at: vaultURL)
            }

            lastSyncDate = Date()
            status = hasRemote ? .idle : .noRemote
        } catch let error as GitError {
            if error.output.contains("CONFLICT") || error.output.contains("conflict") {
                status = .error("Merge conflict — resolve in terminal, then retry")
            } else {
                status = .error(error.output)
            }
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func pullFromRemote(at url: URL) async {
        do {
            try await runGit(["pull", "--rebase", "--autostash"], at: url)
        } catch {
            // Initial pull failure is non-fatal
        }
    }

    // MARK: - Periodic Pull

    private func startPeriodicPull() {
        periodicPullTask?.cancel()
        periodicPullTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300)) // 5 minutes
                guard !Task.isCancelled, hasRemote, let vaultURL else { continue }

                let previousStatus = status
                status = .syncing
                await pullFromRemote(at: vaultURL)
                if status == .syncing {
                    status = previousStatus == .syncing ? .idle : previousStatus
                }
            }
        }
    }

    private func cancelTimers() {
        debounceTask?.cancel()
        debounceTask = nil
        periodicPullTask?.cancel()
        periodicPullTask = nil
    }

    // MARK: - Git Checks

    private func checkIsGitRepo(at url: URL) async -> Bool {
        do {
            try await runGit(["rev-parse", "--is-inside-work-tree"], at: url)
            return true
        } catch {
            return false
        }
    }

    private func checkHasRemote(at url: URL) async -> Bool {
        do {
            let output = try await runGit(["remote"], at: url)
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Git Runner

    private struct GitError: Error {
        let output: String
    }

    @discardableResult
    nonisolated private func runGit(_ arguments: [String], at workingDirectory: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = arguments
            process.currentDirectoryURL = workingDirectory

            let pipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = pipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: GitError(output: error.localizedDescription))
                return
            }

            process.waitUntilExit()

            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                continuation.resume(returning: output)
            } else {
                continuation.resume(throwing: GitError(output: errorOutput.isEmpty ? output : errorOutput))
            }
        }
    }
}
