import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag || MenuBarManager.shared.isMinimizedToMenuBar {
            MenuBarManager.shared.restoreMainWindow()
            return true
        }
        return true
    }
}

@main
struct NXNativeGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainView(viewModel: viewModel)
                .frame(minWidth: 880, idealWidth: 1280, maxWidth: .infinity, minHeight: 620, idealHeight: 800, maxHeight: .infinity)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 1280, height: 800)
        .windowResizability(.contentSize)
        .commands {
            SidebarCommands()
            
            CommandGroup(replacing: .appInfo) {
                Button("About NxNative Launcher") {
                    SoundEffectService.shared.play(.click)
                    viewModel.showAboutSheet = true
                }
            }
            
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    SoundEffectService.shared.play(.click)
                    viewModel.openUpdateCheckerAndAutoInstall()
                }
                .keyboardShortcut("U", modifiers: [.command])
                
                Divider()
            }
            
            CommandGroup(replacing: .windowList) {
                Button(L10n.t("menubar.minimize")) {
                    MenuBarManager.shared.minimizeToMenuBar()
                }
                .keyboardShortcut("M", modifiers: [.command])
            }
            
            CommandGroup(replacing: .appTermination) {
                Button("Quit NxNative Launcher") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
        }
    }
}
