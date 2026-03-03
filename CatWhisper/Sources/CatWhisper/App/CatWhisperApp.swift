import SwiftUI

@main
struct CatWhisperApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            StatusItemIcon(state: appState.state)
                .onAppear {
                    appState.bootstrap()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        Window("歡迎使用 CatWhisper", id: "onboarding") {
            OnboardingView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 500, height: 400)
        .windowResizability(.contentSize)
    }

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
