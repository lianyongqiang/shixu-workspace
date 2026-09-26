import SwiftUI
import AppKit
import DeskCore

private enum Page: String, CaseIterable {
    case home = "工作台", resources = "全部资料", actions = "快捷操作"
    var symbol: String { switch self { case .home: return "square.grid.2x2"; case .resources: return "folder"; case .actions: return "bolt" } }
}

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openWindow) private var openWindow
    @State private var page = Page.home
    @State private var selectedID: UUID?
    @State private var query = ""
    @State private var sceneDraft: SceneDraft?
    @State private var resourceDraft: ResourceDraft?
    @State private var showPreferences = false
    @State private var deleteScene: WorkScene?
    @State private var deleteResource: Resource?
    @State private var showDelete = false
    @FocusState private var searchFocused: Bool
    private var selected: WorkScene? { store.data.scenes.first { $0.id == selectedID } ?? store.data.scenes.first }
    private var recent: [Resource] { Array(store.data.resources.filter { $0.lastOpened != nil }.sorted { ($0.lastOpened ?? .distantPast) > ($1.lastOpened ?? .distantPast) }.prefix(4)) }

    var body: some View {
        Group {
            if let failure = store.loadFailure { recovery(failure) }
            else {
                HStack(spacing: 0) {
                    sidebar.frame(width: 175)
                    Rectangle().fill(Palette.line).frame(width: 1)
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        searchBar
                        ScrollView {
                            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { searchResults }
                            else { switch page { case .home: home; case .resources: allResources; case .actions: actionsPage } }
                        }
                        footer
                    }.padding(26).padding(.top, 12)
                }.background(Palette.background)
            }
        }
        .onAppear {
            if selectedID == nil { selectedID = store.data.scenes.first?.id }
            AppDelegate.showMain = {
                openWindow(id: "main")
                NSApp.windows.first(where: { $0.title == "拾序工作台" })?.makeKeyAndOrderFront(nil)
            }
        }
        .onChange(of: store.data.scenes.map(\.id)) { _, ids in if let selectedID, !ids.contains(selectedID) { self.selectedID = ids.first } }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShixuSearch"))) { _ in searchFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShixuNewScene"))) { _ in newScene() }
        .sheet(item: $sceneDraft) { draft in SceneEditor(draft: draft) { id in selectedID = id; page = .home; query = "" } }
        .sheet(item: $resourceDraft) { ResourceEditor(draft: $0) }
        .sheet(isPresented: $showPreferences) { PreferencesView() }
        .alert(item: $store.notice) { notice in Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("知道了"))) }
        .confirmationDialog(deleteScene != nil ? "删除这个场景？" : "从工作台移除这项资料？", isPresented: $showDelete, titleVisibility: .visible) {
            Button(deleteScene != nil ? "删除场景" : "移除资料", role: .destructive) {
                if let deleteScene { store.removeScene(deleteScene.id) }; if let deleteResource { store.removeResource(deleteResource.id) }
                deleteScene = nil; deleteResource = nil
            }
            Button("取消", role: .cancel) { deleteScene = nil; deleteResource = nil }
        } message: { Text(deleteScene != nil ? "只删除场景，资料入口和电脑上的原文件都会保留。可以撤销。" : "会从所有场景移除该资料入口，电脑上的原文件不会删除。可以撤销。") }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 10) { Image(systemName: "square.grid.2x2").font(.title3).foregroundStyle(.white).frame(width: 32, height: 32).background(Color(red: 0.21, green: 0.40, blue: 0.29), in: RoundedRectangle(cornerRadius: 9)); Text("拾序").font(.title2.weight(.semibold)) }.padding(.horizontal, 12)
            VStack(spacing: 5) {
                ForEach(Page.allCases, id: \.self) { item in
                    Button { page = item; query = "" } label: {
                        HStack(spacing: 10) { Image(systemName: item.symbol).frame(width: 18); Text(item.rawValue); Spacer() }.padding(.horizontal, 12).padding(.vertical, 11).foregroundStyle(page == item ? Palette.accent : .primary).background(page == item ? Palette.surface : .clear, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
            }
            Spacer()
            Button { showPreferences = true } label: { Label("设置与备份", systemImage: "gearshape").font(.callout).foregroundStyle(.secondary) }.buttonStyle(.plain).padding(12)
            Label("⌘⇧空格 呼出", systemImage: "keyboard").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
        }.padding(.horizontal, 12).padding(.top, 48).padding(.bottom, 20).background(Palette.soft)
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(page == .home ? "继续手头的工作" : page == .resources ? "全部资料" : "常用操作，少点几下").font(.system(size: 24, weight: .semibold))
                Text(page == .home ? "常用的网页、文件和应用，都在一个地方。" : page == .resources ? "只搜索你收录到工作台的资料。" : "把重复的操作，变成顺手的一个按钮。").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if page == .resources { Button { resourceDraft = ResourceDraft() } label: { Label("添加资料", systemImage: "plus") } }
            else { Button { newScene() } label: { Label("新建场景", systemImage: "plus") } }
        }
    }
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("搜索场景、文件或网页…", text: $query).textFieldStyle(.plain).focused($searchFocused).accessibilityLabel("搜索资料")
            if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel("清空搜索") }
            Text("⌘ K").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 6).padding(.vertical, 2).background(Palette.background, in: RoundedRectangle(cornerRadius: 4))
        }.padding(13).background(Palette.surface, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line))
    }
    private var home: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text("工作场景").font(.headline); Spacer(); Text("\(store.data.scenes.count) 个场景").font(.caption).foregroundStyle(.secondary) }
            if store.data.scenes.isEmpty {
                empty("创建你的第一个工作场景", detail: "例如“写公众号”，把相关网页和文件放在一起。", symbol: "square.stack.3d.up")
                Button("创建场景") { newScene() }.buttonStyle(.borderedProminent)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    ForEach(store.data.scenes) { scene in sceneCard(scene) }
                }
                if let scene = selected {
                    HStack(alignment: .top, spacing: 20) {
                        scenePanel(scene).frame(maxWidth: .infinity)
                        VStack(alignment: .leading, spacing: 24) { quickActions; recentItems }.frame(width: 220)
                    }
                }
            }
        }.padding(1)
    }
    private func sceneCard(_ scene: WorkScene) -> some View {
        Button { selectedID = scene.id } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack { Image(systemName: scene.symbol).font(.title3).foregroundStyle(Palette.accent).frame(width: 32, height: 32).background(Palette.surface, in: RoundedRectangle(cornerRadius: 8)); Spacer(); if selected?.id == scene.id { Image(systemName: "checkmark.circle").foregroundStyle(Palette.accent) } }
                Text(scene.name).font(.headline).lineLimit(1)
                Text("\(scene.resourceIDs.count) 项资料 · \(scene.lastOpened == nil ? "准备就绪" : "最近使用")").font(.caption).foregroundStyle(.secondary)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(selected?.id == scene.id ? Palette.soft : Palette.surface, in: RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).stroke(selected?.id == scene.id ? Palette.accent : Palette.line))
        }.buttonStyle(.plain).help("选择“\(scene.name)”")
        .contextMenu {
            Button("打开场景") { store.openScene(scene) }.disabled(store.busy)
            Button("编辑场景") { sceneDraft = SceneDraft(scene: scene, isNew: false) }
            Button("删除场景…", role: .destructive) { deleteResource = nil; deleteScene = scene; showDelete = true }
        }
    }
    private func scenePanel(_ scene: WorkScene) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) { Text(scene.name).font(.headline); Text("要一起打开的 \(scene.resourceIDs.count) 项资料").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button { sceneDraft = SceneDraft(scene: scene, isNew: false) } label: { Image(systemName: "slider.horizontal.3") }.buttonStyle(.plain).help("编辑场景、选择已有资料").accessibilityLabel("编辑场景")
                Button { resourceDraft = ResourceDraft(sceneID: scene.id) } label: { Label("添加", systemImage: "plus") }.buttonStyle(.borderless)
            }.padding(17)
            if scene.resourceIDs.isEmpty { empty("还没有资料", detail: "点击右上角“添加”，选择网页、文件或应用。", symbol: "folder.badge.plus").padding(16) }
            ForEach(store.data.resources(in: scene)) { resource in Divider(); resourceRow(resource, scene: scene) }
            Divider()
            Button { store.openScene(scene) } label: { Label(store.busy ? "正在打开…" : "一键打开 \(scene.resourceIDs.count) 项资料", systemImage: "play").frame(maxWidth: .infinity).padding(.vertical, 6) }
                .buttonStyle(.borderedProminent).disabled(store.busy || scene.resourceIDs.isEmpty).padding(15)
        }.background(Palette.surface, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line))
    }
    private func resourceRow(_ resource: Resource, scene: WorkScene? = nil) -> some View {
        HStack(spacing: 10) {
            Image(systemName: resource.kind.symbol).foregroundStyle(.secondary).frame(width: 32, height: 36).background(Palette.background, in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 4) { Text(resource.name).font(.callout.weight(.medium)).lineLimit(1); Text(resource.location).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle) }.frame(maxWidth: .infinity, alignment: .leading).help(resource.location)
            Button { resourceDraft = ResourceDraft(resource: resource) } label: { Image(systemName: "pencil").font(.caption).foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel("编辑\(resource.name)").help("编辑资料")
            Button { store.open([resource]) } label: { Image(systemName: "arrow.up.right").foregroundStyle(Palette.accent) }.buttonStyle(.plain).disabled(store.busy).accessibilityLabel("打开\(resource.name)").help("打开资料")
        }.padding(.horizontal, 16).padding(.vertical, 12)
        .contextMenu {
            Button("打开") { store.open([resource]) }.disabled(store.busy)
            Button("编辑资料") { resourceDraft = ResourceDraft(resource: resource) }
            if resource.kind != .website { Button("在 Finder 中显示") { store.reveal(resource) } }
            if let scene {
                Button("上移") { store.move(resource.id, in: scene.id, offset: -1) }.disabled(scene.resourceIDs.first == resource.id)
                Button("下移") { store.move(resource.id, in: scene.id, offset: 1) }.disabled(scene.resourceIDs.last == resource.id)
                Button("从这个场景移除") { store.detach(resource.id, from: scene.id) }
            } else {
                Button("从工作台移除…", role: .destructive) { deleteScene = nil; deleteResource = resource; showDelete = true }
            }
        }
    }
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("快捷操作").font(.headline).padding(.bottom, 10)
            actionRow("打开下载文件夹", symbol: "arrow.down.to.line") { store.openFolder(.downloadsDirectory) }
            Divider()
            actionRow("打开桌面", symbol: "desktopcomputer") { store.openFolder(.desktopDirectory) }
            Divider()
            actionRow("建立今日工作场景", symbol: "calendar.badge.plus") { newScene(today: true) }
        }
    }
    private func actionRow(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack(spacing: 10) { Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 20); Text(title).font(.callout); Spacer(); Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary) }.padding(.vertical, 12) }.buttonStyle(.plain)
    }
    private var recentItems: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近使用").font(.headline)
            if recent.isEmpty { Text("通过工作台打开的资料会出现在这里。").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            ForEach(recent) { resource in
                Button { store.open([resource]) } label: { HStack { Image(systemName: resource.kind.symbol).foregroundStyle(.secondary); Text(resource.name).lineLimit(1); Spacer() }.font(.callout).padding(.vertical, 6) }.buttonStyle(.plain).disabled(store.busy)
            }
        }
    }
    private var allResources: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("已收录资料").font(.headline); Spacer(); Text("\(store.data.resources.count) 项").foregroundStyle(.secondary) }
            if store.data.resources.isEmpty { empty("把常用资料放进来", detail: "点击“添加资料”，先加入一个常用网页或文件夹。", symbol: "folder.badge.plus") }
            else { VStack(spacing: 0) { ForEach(store.data.resources) { resource in resourceRow(resource); if resource.id != store.data.resources.last?.id { Divider() } } }.background(Palette.surface, in: RoundedRectangle(cornerRadius: 12)) }
        }
    }
    private var searchResults: some View {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let scenes = store.data.scenes.filter { scene in term.split(whereSeparator: { $0.isWhitespace }).allSatisfy { scene.name.localizedStandardContains(String($0)) } }
        let resources = store.data.resources.filter { $0.matches(term) }
        return VStack(alignment: .leading, spacing: 14) {
            Text("找到 \(scenes.count + resources.count) 项").font(.headline)
            ForEach(scenes) { scene in
                Button { selectedID = scene.id; page = .home; query = "" } label: { HStack { Image(systemName: scene.symbol).foregroundStyle(Palette.accent); VStack(alignment: .leading) { Text(scene.name); Text("工作场景 · \(scene.resourceIDs.count) 项资料").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right") }.padding(15).background(Palette.soft, in: RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain)
            }
            VStack(spacing: 0) { ForEach(resources) { resource in resourceRow(resource); if resource.id != resources.last?.id { Divider() } } }.background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
            if scenes.isEmpty && resources.isEmpty { empty("没有找到相关资料", detail: "试试场景名称、文件名或网址。搜索范围是你已收录的资料。", symbol: "magnifyingglass") }
        }
    }
    private var actionsPage: some View {
        VStack(alignment: .leading, spacing: 24) { quickActions.padding(20).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12)); Text("把多个资料一起打开，可以在“工作台”中创建场景。").font(.callout).foregroundStyle(.secondary); Spacer() }
    }
    private var footer: some View {
        HStack(spacing: 8) {
            if store.busy { ProgressView().controlSize(.small) } else { Image(systemName: "checkmark.circle").foregroundStyle(Palette.accent) }
            Text(store.status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Spacer()
            if store.undoData != nil { Button("撤销") { store.undo() }.font(.caption).buttonStyle(.borderless).disabled(store.busy) }
        }.frame(minHeight: 22)
    }
    private func empty(_ title: String, detail: String, symbol: String) -> some View {
        VStack(spacing: 12) { Image(systemName: symbol).font(.system(size: 30)).foregroundStyle(Palette.accent); Text(title).font(.headline); Text(detail).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center) }.padding(25).frame(maxWidth: .infinity)
    }
    private func recovery(_ failure: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle).foregroundStyle(.orange)
            Text("工作台资料暂时无法读取").font(.title2)
            Text("原文件已保留，没有创建新数据覆盖它。").foregroundStyle(.secondary)
            Text(failure).font(.callout).textSelection(.enabled).frame(maxWidth: 520)
            HStack { Button("打开资料目录") { store.openDataFolder() }; Button("恢复上一次保存") { store.recover() }.buttonStyle(.borderedProminent) }
        }.padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func newScene(today: Bool = false) {
        let formatter = DateFormatter(); formatter.dateFormat = "M月d日"
        sceneDraft = SceneDraft(scene: WorkScene(name: today ? "今日工作 · \(formatter.string(from: Date()))" : "", symbol: "folder"), isNew: true)
    }
}
