import SwiftUI

struct GitSyncStatusView: View {
    let gitSyncManager: GitSyncManager

    @State private var isRotating = false

    var body: some View {
        if gitSyncManager.isEnabled && gitSyncManager.status != .disabled && gitSyncManager.status != .notARepo {
            Button(action: { gitSyncManager.manualSync() }) {
                statusIcon
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(tooltipText)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch gitSyncManager.status {
        case .idle:
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(Monokai.string)
        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(Monokai.function)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isRotating)
                .onAppear { isRotating = true }
                .onChange(of: gitSyncManager.status) {
                    isRotating = gitSyncManager.status == .syncing
                }
        case .error:
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(Monokai.keyword)
        case .noRemote:
            Image(systemName: "internaldrive")
                .foregroundStyle(Monokai.comment)
        case .disabled, .notARepo:
            EmptyView()
        }
    }

    private var tooltipText: String {
        switch gitSyncManager.status {
        case .idle:
            if let date = gitSyncManager.lastSyncDate {
                return "Synced — \(date.formatted(date: .omitted, time: .shortened))"
            }
            return "Git Sync — Up to date"
        case .syncing:
            return "Syncing..."
        case .error(let message):
            return "Sync error: \(message)"
        case .noRemote:
            return "Local only — no remote configured"
        case .disabled, .notARepo:
            return ""
        }
    }
}
