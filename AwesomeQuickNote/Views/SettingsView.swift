import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    let vaultManager: VaultManager
    var onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader("Keyboard Shortcuts")
                shortcutsSection

                Divider().background(Monokai.border)

                sectionHeader("Vault")
                vaultSection

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
            .background(Monokai.toolbarBackground.opacity(0.9))
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
