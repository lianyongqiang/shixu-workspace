import AppKit
import SwiftUI
import UniformTypeIdentifiers
import DeskCore

struct Notice: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var data = WorkspaceData()
    @Published var status = "选择一个场景，接着上次的工作。"
    @Published var notice: Notice?
    @Published private(set) var loadFailure: String?
    @Published private(set) var busy = false
    @Published private(set) var undoData: WorkspaceData?
    let disk: DiskStore

    init(directory: URL? = nil) {
        let defaultDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ShixuWorkspace", isDirectory: true)
        disk = DiskStore(directory: directory ?? defaultDirectory)
        do {
            if let saved = try disk.load() { data = saved }
            else { let initial = WorkspaceData.starter(); try disk.save(initial); data = initial; status = "已准备两个常用场景。添加你的素材文件，就能一起打开。" }
        } catch { loadFailure = error.localizedDescription; status = "资料暂时无法读取；原文件已保留。" }
    }
    @discardableResult
    func commit(_ next: WorkspaceData, message: String, undoable: Bool = true) -> Bool {
        guard loadFailure == nil else { return false }
        do {
            try disk.save(next)
            if undoable { undoData = data }
            data = next; status = message; return true
        } catch { notice = Notice(title: "没有保存成功", message: "\(error.localizedDescription)\n更改没有覆盖之前的工作台，请检查磁盘空间或文件夹权限。"); return false }
    }
    func undo() {
        guard let old = undoData else { return }
        if commit(old, message: "已撤销上一次修改。", undoable: false) { undoData = nil }
    }
    @discardableResult
    func saveResource(_ resource: Resource, sceneID: UUID?) -> Bool {
        var next = data; next.upsert(resource, into: sceneID)
        return commit(next, message: "已保存“\(resource.name)”。")
    }
    @discardableResult
    func saveScene(_ scene: WorkScene) -> Bool {
        var next = data
        if let index = next.scenes.firstIndex(where: { $0.id == scene.id }) { next.scenes[index] = scene } else { next.scenes.append(scene) }
        return commit(next, message: "已保存“\(scene.name)”。")
    }
    func removeScene(_ id: UUID) { var next = data; next.scenes.removeAll { $0.id == id }; _ = commit(next, message: "场景已删除；资料仍在“全部资料”中，可撤销。") }
    func removeResource(_ id: UUID) { var next = data; next.removeResource(id); _ = commit(next, message: "已从工作台移除资料，电脑上的原文件未删除，可撤销。") }
    func detach(_ id: UUID, from sceneID: UUID) {
        var next = data
        guard let index = next.scenes.firstIndex(where: { $0.id == sceneID }) else { return }
        next.scenes[index].resourceIDs.removeAll { $0 == id }
        _ = commit(next, message: "已从这个场景移除；资料仍在“全部资料”中。")
    }
    func move(_ id: UUID, in sceneID: UUID, offset: Int) {
        var next = data
        guard let si = next.scenes.firstIndex(where: { $0.id == sceneID }), let ri = next.scenes[si].resourceIDs.firstIndex(of: id) else { return }
        let destination = ri + offset
        guard next.scenes[si].resourceIDs.indices.contains(destination) else { return }
        next.scenes[si].resourceIDs.swapAt(ri, destination)
        _ = commit(next, message: "已调整资料的打开顺序。")
    }
    func recover() {
        do { data = try disk.recoverPrevious(); loadFailure = nil; status = "已恢复上一次保存；原文件也已留存。" }
        catch { notice = Notice(title: "无法恢复", message: error.localizedDescription) }
    }
    func openDataFolder() { NSWorkspace.shared.open(disk.directory) }
    func exportBackup() {
        let panel = NSSavePanel(); panel.title = "导出工作台备份"; panel.nameFieldStringValue = "拾序工作台备份.json"; panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try data.encoded().write(to: url, options: .atomic); status = "备份已导出到“\(url.lastPathComponent)”。" }
        catch { notice = Notice(title: "导出失败", message: error.localizedDescription) }
    }
    func chooseImport() -> WorkspaceData? {
        let panel = NSOpenPanel(); panel.title = "选择拾序备份"; panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do { return try WorkspaceData.decode(Data(contentsOf: url)) }
        catch { notice = Notice(title: "无法导入此备份", message: error.localizedDescription); return nil }
    }
    func reveal(_ resource: Resource) {
        do { let url = try resource.resolvedURL(); NSWorkspace.shared.activateFileViewerSelecting([url]) }
        catch { notice = Notice(title: "找不到资料", message: error.localizedDescription) }
    }
    func openScene(_ scene: WorkScene) { open(data.resources(in: scene), sceneID: scene.id) }
    func open(_ resources: [Resource], sceneID: UUID? = nil) {
        guard !busy, loadFailure == nil else { return }
        guard !resources.isEmpty else { status = "先为这个场景添加资料。"; return }
        busy = true; status = "正在打开 \(resources.count) 项资料…"
        Task {
            var successful = Set<UUID>(); var failures: [String] = []
            for (index, resource) in resources.enumerated() {
                status = "正在打开 \(index + 1)/\(resources.count)：\(resource.name)"
                do { try await openURL(resource.resolvedURL(), preferChrome: resource.kind == .website && data.preferChrome); successful.insert(resource.id) }
                catch { failures.append("• \(resource.name)：\(error.localizedDescription)") }
            }
            var next = data; next.recordOpen(successful, sceneID: sceneID)
            if !successful.isEmpty { _ = commit(next, message: "已打开 \(successful.count) 项资料。", undoable: false) }
            busy = false
            if !failures.isEmpty {
                status = "已打开 \(successful.count) 项，\(failures.count) 项未能打开。"
                notice = Notice(title: "部分资料没有打开", message: failures.joined(separator: "\n\n"))
            }
        }
    }
    private func openURL(_ url: URL, preferChrome: Bool) async throws {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let completion: (NSRunningApplication?, Error?) -> Void = { app, error in
                if let error { continuation.resume(throwing: error) }
                else if app != nil { continuation.resume() }
                else { continuation.resume(throwing: WorkspaceError.invalid("系统没有找到可打开它的应用。")) }
            }
            if preferChrome, let chrome = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
                NSWorkspace.shared.open([url], withApplicationAt: chrome, configuration: config, completionHandler: completion)
            } else { NSWorkspace.shared.open(url, configuration: config, completionHandler: completion) }
        }
    }
    func openFolder(_ directory: FileManager.SearchPathDirectory) {
        guard let url = FileManager.default.urls(for: directory, in: .userDomainMask).first else { return }
        if !NSWorkspace.shared.open(url) { notice = Notice(title: "无法打开文件夹", message: url.path) }
        else { status = "已打开“\(url.lastPathComponent)”。" }
    }
}
