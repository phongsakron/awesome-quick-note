import SwiftUI

struct MenuBarView: View {
    let panelController: FloatingPanelController
    let vaultManager: VaultManager

    var body: some View {
        Button(panelController.isVisible ? "Hide Panel" : "Show Panel") {
            panelController.togglePanel()
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Button("New Note") {
            panelController.createNewNote()
        }
        .keyboardShortcut("n", modifiers: [.command, .option])

        Button("Search Notes") {
            panelController.showSearch()
        }
        .keyboardShortcut("f", modifiers: [.command, .shift])

        Divider()

        Menu("Position") {
            ForEach(PanelPosition.allCases, id: \.self) { position in
                Button(position.displayName) {
                    panelController.moveToPosition(position)
                }
            }
        }

        Divider()

        Button("Settings...") {
            panelController.showSettings()
        }

        Button("Change Vault...") {
            vaultManager.selectVault()
        }

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
