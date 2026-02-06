import SwiftUI

struct VaultSetupView: View {
    let vaultManager: VaultManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 48))
                .foregroundStyle(Monokai.type)

            Text("Welcome to AwesomeQuickNote")
                .font(.title2.bold())
                .foregroundStyle(Monokai.foreground)

            Text("Choose a folder to store your markdown notes.")
                .font(.body)
                .foregroundStyle(Monokai.comment)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button(action: selectVault) {
                    Label("Select Existing Folder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(Monokai.keyword)

                Button(action: createVault) {
                    Label("Create New Vault", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(Monokai.function)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectVault() {
        vaultManager.selectVault()
    }

    private func createVault() {
        vaultManager.createVault()
    }
}
