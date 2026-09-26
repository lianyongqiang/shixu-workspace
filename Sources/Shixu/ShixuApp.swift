import SwiftUI
import AppKit
import Carbon

@main
struct ShixuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = AppStore()
    var body: some Scene {
        Window("拾序工作台", id: "main") {
            ContentView().environmentObject(store)
                .tint(Palette.accent)
                .frame(minWidth: 820, minHeight: 570)
        }
        .defaultSize(width: 1100, height: 780)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建场景…") { NotificationCenter.default.post(name: Notification.Name("ShixuNewScene"), object: nil) }.keyboardShortcut("n").disabled(store.loadFailure != nil)
            }
            CommandMenu("工作台") {
                Button("搜索资料") { NotificationCenter.default.post(name: Notification.Name("ShixuSearch"), object: nil) }.keyboardShortcut("k")
            }
            CommandGroup(replacing: .undoRedo) {
                Button("撤销上一次修改") { store.undo() }.keyboardShortcut("z").disabled(store.undoData == nil)
            }
            CommandGroup(after: .saveItem) {
                Button("导出工作台备份…") { store.exportBackup() }.disabled(store.loadFailure != nil)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var showMain: (() -> Void)?
    private var statusItem: NSStatusItem?
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "拾序工作台")
        item.button?.toolTip = "拾序工作台 · ⌘⇧空格"
        let menu = NSMenu()
        let show = NSMenuItem(title: "打开拾序工作台", action: #selector(showWindow), keyEquivalent: ""); show.target = self; menu.addItem(show)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出拾序", action: #selector(quitApp), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
        item.menu = menu; statusItem = item
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            Task { @MainActor in AppDelegate.showMain?(); NSApp.activate(ignoringOtherApps: true) }
            return noErr
        }, 1, &eventType, nil, &eventHandler)
        let result = RegisterEventHotKey(UInt32(kVK_Space), UInt32(cmdKey | shiftKey), EventHotKeyID(signature: 0x53585157, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr { item.button?.toolTip = "拾序工作台 · 快捷键已被其他应用占用，请点击打开" }
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func showWindow() { Self.showMain?(); NSApp.activate(ignoringOtherApps: true) }
    @objc func quitApp() { NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationWillTerminate(_ notification: Notification) { if let hotKey { UnregisterEventHotKey(hotKey) }; if let eventHandler { RemoveEventHandler(eventHandler) } }
}

enum Palette {
    static let accent = Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(calibratedRed: 0.64, green: 0.81, blue: 0.69, alpha: 1) : NSColor(calibratedRed: 0.21, green: 0.40, blue: 0.29, alpha: 1) })
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let line = Color.primary.opacity(0.10)
    static let soft = accent.opacity(0.08)
}
