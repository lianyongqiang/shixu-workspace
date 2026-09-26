import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DeskCore

struct SceneDraft: Identifiable {
    let id = UUID()
    var scene: WorkScene
    var isNew: Bool
}
struct ResourceDraft: Identifiable {
    let id = UUID()
    var resource: Resource?
    var sceneID: UUID?
}

struct SceneEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var scene: WorkScene
    @State private var error: String?
    let isNew: Bool
    let onSave: (UUID) -> Void
    private let symbols = ["square.and.pencil", "book", "folder", "video", "briefcase", "paintpalette"]
    init(draft: SceneDraft, onSave: @escaping (UUID) -> Void) {
        _scene = State(initialValue: draft.scene); isNew = draft.isNew; self.onSave = onSave
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text(isNew ? "创建工作场景" : "编辑工作场景").font(.title2.weight(.semibold)); Spacer(); Button("取消") { dismiss() }.keyboardShortcut(.cancelAction) }
            TextField("场景名称，例如：写公众号", text: $scene.name).textFieldStyle(.roundedBorder)
            HStack(spacing: 12) {
                Text("图标").foregroundStyle(.secondary)
                ForEach(symbols, id: \.self) { symbol in
                    Button { scene.symbol = symbol } label: { Image(systemName: symbol).frame(width: 32, height: 30).background(scene.symbol == symbol ? Palette.soft : .clear, in: RoundedRectangle(cornerRadius: 7)) }
                        .buttonStyle(.plain).accessibilityLabel("选择图标 \(symbol)")
                }
            }
            Text("选择要一起打开的资料").font(.headline)
            if store.data.resources.isEmpty { Text("可以先创建场景，再添加网页、文件或应用。").foregroundStyle(.secondary) }
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(store.data.resources) { resource in
                        Toggle(isOn: Binding(get: { scene.resourceIDs.contains(resource.id) }, set: { value in if value { scene.resourceIDs.append(resource.id) } else { scene.resourceIDs.removeAll { $0 == resource.id } } })) {
                            Label(resource.name, systemImage: resource.kind.symbol).lineLimit(1)
                        }.toggleStyle(.checkbox).padding(.vertical, 9)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 230)
            if let error { Text(error).foregroundStyle(.red).font(.caption) }
            HStack { Text("只保存资料入口，不移动原文件。").font(.caption).foregroundStyle(.secondary); Spacer(); Button(isNew ? "创建场景" : "保存修改") { save() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction) }
        }.padding(26).frame(width: 520)
    }
    private func save() {
        scene.name = String(scene.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !scene.name.isEmpty else { error = "请给场景起一个名字。"; return }
        if store.saveScene(scene) { onSave(scene.id); dismiss() }
        else { error = "保存失败，请检查磁盘空间与资料目录权限。" }
    }
}

struct ResourceEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var kind: ResourceKind
    @State private var location: String
    @State private var bookmark: Data?
    @State private var error: String?
    let draft: ResourceDraft
    init(draft: ResourceDraft) {
        self.draft = draft
        _name = State(initialValue: draft.resource?.name ?? "")
        _kind = State(initialValue: draft.resource?.kind ?? .website)
        _location = State(initialValue: draft.resource?.location ?? "")
        _bookmark = State(initialValue: draft.resource?.bookmark)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text(draft.resource == nil ? "添加资料" : "编辑资料").font(.title2.weight(.semibold)); Spacer(); Button("取消") { dismiss() }.keyboardShortcut(.cancelAction) }
            Picker("资料类型", selection: $kind) { ForEach(ResourceKind.allCases) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                .onChange(of: kind) { _, _ in location = ""; bookmark = nil; error = nil }
            VStack(alignment: .leading, spacing: 8) { Text("名称").font(.headline); TextField("例如：公众号素材", text: $name).textFieldStyle(.roundedBorder) }
            if kind == .website {
                VStack(alignment: .leading, spacing: 8) { Text("网址").font(.headline); TextField("https://…", text: $location).textFieldStyle(.roundedBorder); Text("网页会用设置中选择的浏览器打开。").font(.caption).foregroundStyle(.secondary) }
            } else {
                HStack { Text(kind == .application ? "应用位置" : "资料位置").font(.headline); Spacer(); Button("选择\(kind.label)…") { choose() } }
                Text(location.isEmpty ? "请选择这台 Mac 上的\(kind.label)。" : location).font(.callout).foregroundStyle(.secondary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Palette.background, in: RoundedRectangle(cornerRadius: 8))
            }
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack { Spacer(); Button("保存资料") { save() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction) }
        }.padding(26).frame(width: 540)
    }
    private func choose() {
        let panel = NSOpenPanel(); panel.title = "选择\(kind.label)"; panel.prompt = "添加"; panel.allowsMultipleSelection = false
        panel.canChooseDirectories = kind == .folder; panel.canChooseFiles = kind != .folder
        if kind == .application { panel.allowedContentTypes = [.applicationBundle]; panel.directoryURL = URL(fileURLWithPath: "/Applications") }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        location = url.path; bookmark = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { name = kind == .application ? url.deletingPathExtension().lastPathComponent : url.lastPathComponent }
        error = nil
    }
    private func save() {
        let title = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        guard !title.isEmpty else { error = "请输入资料名称。"; return }
        do {
            let address = kind == .website ? try Resource.websiteURL(location).absoluteString : location
            var resource = Resource(id: draft.resource?.id ?? UUID(), name: title, kind: kind, location: address, bookmark: bookmark, lastOpened: draft.resource?.lastOpened)
            if kind != .website { let actual = try resource.resolvedURL(); resource.location = actual.path }
            if store.saveResource(resource, sceneID: draft.sceneID) { dismiss() }
            else { error = "保存失败，请检查磁盘空间与资料目录权限。" }
        } catch { self.error = error.localizedDescription }
    }
}

struct PreferencesView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var importData: WorkspaceData?
    @State private var confirmImport = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { Text("设置与备份").font(.title2.weight(.semibold)); Spacer(); Button("完成") { dismiss() }.keyboardShortcut(.cancelAction) }
            Picker("网页打开方式", selection: Binding(get: { store.data.preferChrome }, set: { value in var data = store.data; data.preferChrome = value; _ = store.commit(data, message: "已更新浏览器设置。") })) { Text("Google Chrome（未安装时用系统默认）").tag(true); Text("系统默认浏览器").tag(false) }
            Divider()
            Text("工作台保存在这台 Mac 上").font(.headline)
            Text("备份包含场景、名称和资料位置，不包含原文件。换电脑后，本地文件可能需要重新选择。").font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("导出备份…") { store.exportBackup() }
                Button("导入备份…") { if let data = store.chooseImport() { importData = data; confirmImport = true } }
                Button("打开资料目录") { store.openDataFolder() }
            }
            Divider()
            Label("⌘⇧空格：随时呼出工作台", systemImage: "keyboard")
            Text("关闭窗口后，仍可从顶部菜单栏打开。退出应用请按 ⌘Q。").font(.caption).foregroundStyle(.secondary)
        }.padding(28).frame(width: 570)
        .alert("用备份替换当前工作台？", isPresented: $confirmImport) {
            Button("取消", role: .cancel) { importData = nil }
            Button("替换工作台") { if let importData { _ = store.commit(importData, message: "已导入备份，可撤销。") }; importData = nil }
        } message: { Text("当前场景和资料入口将被替换，原文件不会改动。可以通过“撤销上一次修改”恢复。") }
    }
}
