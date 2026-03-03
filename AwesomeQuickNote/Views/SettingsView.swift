import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    let vaultManager: VaultManager
    let panelController: FloatingPanelController
    @Bindable var fontSettings: FontSettings
    let gitSyncManager: GitSyncManager
    var onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader("Keyboard Shortcuts")
                shortcutsSection

                Divider().background(Monokai.border)

                sectionHeader("Panel")
                panelSection

                Divider().background(Monokai.border)

                sectionHeader("Editor")
                editorSection

                Divider().background(Monokai.border)

                sectionHeader("Vault")
                vaultSection

                Divider().background(Monokai.border)

                sectionHeader("Git Sync")
                gitSyncSection

                Divider().background(Monokai.border)

                sectionHeader("About")
                aboutSection
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button("Done", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .tint(Monokai.keyword)
                Spacer()
            }
            .padding(.vertical, 10)
            .background(Monokai.toolbarBackground)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Monokai.type)
            .textCase(.uppercase)
    }

    private var shortcutsSection: some View {
        VStack(spacing: 12) {
            shortcutRow("Toggle Panel", name: .togglePanel)
            shortcutRow("New Note", name: .newNote)
            shortcutRow("Search Notes", name: .searchNotes)
            shortcutRow("Toggle Pin", name: .togglePin)
            shortcutRow("Reset Position", name: .resetPosition)
        }
        .padding(12)
        .background(Monokai.tabBackground.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func shortcutRow(_ label: String, name: KeyboardShortcuts.Name) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Monokai.foreground)
                .frame(width: 110, alignment: .leading)

            KeyboardShortcuts.Recorder(for: name)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var panelSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Position")
                .font(.system(size: 13))
                .foregroundStyle(Monokai.foreground)

            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    positionButton(.topLeft)
                    positionButton(nil)
                    positionButton(.topRight)
                }
                GridRow {
                    positionButton(.left)
                    positionButton(.center)
                    positionButton(.right)
                }
                GridRow {
                    positionButton(.bottomLeft)
                    positionButton(nil)
                    positionButton(.bottomRight)
                }
            }

            Divider().background(Monokai.border)

            HStack {
                Text("Opacity")
                    .font(.system(size: 13))
                    .foregroundStyle(Monokai.foreground)
                    .frame(width: 110, alignment: .leading)

                Slider(value: Bindable(panelController).panelOpacity, in: 0.3...1.0, step: 0.05)
                    .frame(maxWidth: .infinity)

                Text("\(Int(panelController.panelOpacity * 100))%")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Monokai.comment)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(12)
        .background(Monokai.tabBackground.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func positionButton(_ position: PanelPosition?) -> some View {
        Group {
            if let position {
                Button(action: { panelController.moveToPosition(position) }) {
                    Text(position.displayName)
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(Monokai.function)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
            }
        }
    }

    private var editorSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Font Family")
                    .font(.system(size: 13))
                    .foregroundStyle(Monokai.foreground)
                    .frame(width: 110, alignment: .leading)

                Picker("", selection: $fontSettings.fontFamily) {
                    ForEach(fontSettings.availableMonospacedFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Text("Font Size")
                    .font(.system(size: 13))
                    .foregroundStyle(Monokai.foreground)
                    .frame(width: 110, alignment: .leading)

                Button(action: { fontSettings.fontSize = max(10, fontSettings.fontSize - 1) }) {
                    Image(systemName: "minus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .tint(Monokai.type)

                Text("\(Int(fontSettings.fontSize)) pt")
                    .font(.system(size: 13))
                    .foregroundStyle(Monokai.foreground)
                    .frame(width: 44)

                Button(action: { fontSettings.fontSize = min(28, fontSettings.fontSize + 1) }) {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .tint(Monokai.type)

                Slider(value: $fontSettings.fontSize, in: 10...28, step: 1)
                    .frame(maxWidth: .infinity)
            }

            Text("The quick brown fox jumps over the lazy dog")
                .font(.custom(fontSettings.fontFamily, size: fontSettings.fontSize))
                .foregroundStyle(Monokai.foreground)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Monokai.background.opacity(0.5))
                .clipShape(.rect(cornerRadius: 4))
        }
        .padding(12)
        .background(Monokai.tabBackground.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private var vaultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let url = vaultManager.vaultURL {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Monokai.string)
                    Text(url.path)
                        .font(.system(size: 12))
                        .foregroundStyle(Monokai.foreground)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            HStack(spacing: 10) {
                Button("Change Vault") {
                    vaultManager.selectVault()
                }
                .buttonStyle(.bordered)
                .tint(Monokai.function)

                Button("Reveal in Finder") {
                    revealVault()
                }
                .buttonStyle(.bordered)
                .tint(Monokai.type)
            }
        }
        .padding(12)
        .background(Monokai.tabBackground.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private var gitSyncSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Enable Git Sync", isOn: Bindable(gitSyncManager).isEnabled)
                .font(.system(size: 13))
                .foregroundStyle(Monokai.foreground)
                .toggleStyle(.switch)
                .tint(Monokai.string)

            if gitSyncManager.isEnabled {
                HStack(spacing: 6) {
                    statusIndicator
                    Text(statusText)
                        .font(.system(size: 12))
                        .foregroundStyle(Monokai.comment)
                        .lineLimit(2)
                }

                if let date = gitSyncManager.lastSyncDate {
                    Text("Last sync: \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundStyle(Monokai.comment)
                }

                if case .error = gitSyncManager.status {
                    Button("Retry Sync") {
                        gitSyncManager.manualSync()
                    }
                    .buttonStyle(.bordered)
                    .tint(Monokai.keyword)
                }
            }
        }
        .padding(12)
        .background(Monokai.tabBackground.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch gitSyncManager.status {
        case .idle:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Monokai.string)
                .font(.system(size: 12))
        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(Monokai.function)
                .font(.system(size: 12))
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Monokai.keyword)
                .font(.system(size: 12))
        case .noRemote:
            Image(systemName: "internaldrive")
                .foregroundStyle(Monokai.comment)
                .font(.system(size: 12))
        case .notARepo:
            Image(systemName: "xmark.circle")
                .foregroundStyle(Monokai.comment)
                .font(.system(size: 12))
        case .disabled:
            EmptyView()
        }
    }

    private var statusText: String {
        switch gitSyncManager.status {
        case .idle: return "Connected and synced"
        case .syncing: return "Syncing..."
        case .error(let msg): return msg
        case .noRemote: return "Local commits only — no remote configured"
        case .notARepo: return "Vault is not a Git repository"
        case .disabled: return ""
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AwesomeQuickNote")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Monokai.foreground)
            Text("A lightweight menu bar note-taking app")
                .font(.system(size: 12))
                .foregroundStyle(Monokai.comment)
            Text("Version 1.0")
                .font(.system(size: 11))
                .foregroundStyle(Monokai.comment)
        }
        .padding(12)
        .background(Monokai.tabBackground.opacity(0.5))
        .clipShape(.rect(cornerRadius: 8))
    }

    private func revealVault() {
        guard let url = vaultManager.vaultURL else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}
