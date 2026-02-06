import SwiftUI

@main
struct AwesomeQuickNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("AwesomeQuickNote", systemImage: "note.text") {
            MenuBarView(
                panelController: appDelegate.panelController,
                vaultManager: appDelegate.vaultManager
            )
        }
        .menuBarExtraStyle(.menu)
    }
}
