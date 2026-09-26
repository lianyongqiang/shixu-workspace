import Foundation

public enum ResourceKind: String, Codable, CaseIterable, Identifiable {
    case website, file, folder, application
    public var id: String { rawValue }
    public var label: String {
        switch self { case .website: return "网页"; case .file: return "文件"; case .folder: return "文件夹"; case .application: return "应用" }
    }
    public var symbol: String {
        switch self { case .website: return "globe"; case .file: return "doc.text"; case .folder: return "folder"; case .application: return "app" }
    }
}

public enum WorkspaceError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

public struct Resource: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var kind: ResourceKind
    public var location: String
    public var bookmark: Data?
    public var lastOpened: Date?

    public init(id: UUID = UUID(), name: String, kind: ResourceKind, location: String, bookmark: Data? = nil, lastOpened: Date? = nil) {
        self.id = id; self.name = name; self.kind = kind; self.location = location; self.bookmark = bookmark; self.lastOpened = lastOpened
    }
    public static func websiteURL(_ value: String) throws -> URL {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace }) else { throw WorkspaceError.invalid("请输入完整的网址，例如 https://github.com。") }
        let raw = trimmed.contains(":") ? trimmed : "https://" + trimmed
        guard let parts = URLComponents(string: raw), let scheme = parts.scheme?.lowercased(), ["http", "https"].contains(scheme), let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil, let url = parts.url else {
            throw WorkspaceError.invalid("只支持 http 或 https 网页地址；网址中不能包含账号密码。")
        }
        return url
    }
    public func resolvedURL() throws -> URL {
        if kind == .website { return try Self.websiteURL(location) }
        if let bookmark {
            var stale = false
            if let resolved = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale), FileManager.default.fileExists(atPath: resolved.path) { return resolved }
        }
        guard location.hasPrefix("/") else { throw WorkspaceError.invalid("资料路径无效，请重新选择文件。") }
        let url = URL(fileURLWithPath: location)
        guard FileManager.default.fileExists(atPath: url.path) else { throw WorkspaceError.invalid("“\(name)”已移动或不存在，请点“编辑资料”重新选择。") }
        return url
    }
    public func matches(_ query: String) -> Bool {
        let tokens = query.split(whereSeparator: { $0.isWhitespace })
        let haystack = name + " " + location + " " + kind.label
        return tokens.allSatisfy { haystack.localizedStandardContains(String($0)) }
    }
}

public struct WorkScene: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var symbol: String
    public var resourceIDs: [UUID]
    public var lastOpened: Date?
    public init(id: UUID = UUID(), name: String, symbol: String = "folder", resourceIDs: [UUID] = [], lastOpened: Date? = nil) {
        self.id = id; self.name = name; self.symbol = symbol; self.resourceIDs = resourceIDs; self.lastOpened = lastOpened
    }
}

public struct WorkspaceData: Codable, Equatable {
    public var version = 1
    public var resources: [Resource]
    public var scenes: [WorkScene]
    public var preferChrome: Bool
    public init(resources: [Resource] = [], scenes: [WorkScene] = [], preferChrome: Bool = true) {
        self.resources = resources; self.scenes = scenes; self.preferChrome = preferChrome
    }
    public static func starter() -> WorkspaceData {
        let chat = Resource(name: "ChatGPT", kind: .website, location: "https://chatgpt.com")
        let wechat = Resource(name: "微信公众号后台", kind: .website, location: "https://mp.weixin.qq.com")
        let github = Resource(name: "GitHub", kind: .website, location: "https://github.com")
        return WorkspaceData(resources: [chat, wechat, github], scenes: [
            WorkScene(name: "写公众号", symbol: "square.and.pencil", resourceIDs: [chat.id, wechat.id]),
            WorkScene(name: "AI 学习", symbol: "book", resourceIDs: [chat.id, github.id])
        ])
    }
    public func validate() throws {
        guard version == 1 else { throw WorkspaceError.invalid("此备份的版本不受支持，请使用创建它的应用版本。") }
        guard Set(resources.map(\.id)).count == resources.count, Set(scenes.map(\.id)).count == scenes.count else { throw WorkspaceError.invalid("资料标识重复，无法读取此工作台。") }
        let ids = Set(resources.map(\.id))
        for resource in resources {
            guard !resource.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !resource.location.isEmpty else { throw WorkspaceError.invalid("资料名称或地址为空。") }
            if resource.kind == .website { _ = try Resource.websiteURL(resource.location) }
            else if !resource.location.hasPrefix("/") { throw WorkspaceError.invalid("本地资料必须使用完整路径。") }
        }
        for scene in scenes {
            guard !scene.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, Set(scene.resourceIDs).count == scene.resourceIDs.count, scene.resourceIDs.allSatisfy({ ids.contains($0) }) else { throw WorkspaceError.invalid("工作场景的名称或资料关联无效。") }
        }
    }
    public func resources(in scene: WorkScene) -> [Resource] { scene.resourceIDs.compactMap { id in resources.first { $0.id == id } } }
    public mutating func upsert(_ resource: Resource, into sceneID: UUID? = nil) {
        if let index = resources.firstIndex(where: { $0.id == resource.id }) { resources[index] = resource } else { resources.append(resource) }
        if let sceneID, let index = scenes.firstIndex(where: { $0.id == sceneID }), !scenes[index].resourceIDs.contains(resource.id) { scenes[index].resourceIDs.append(resource.id) }
    }
    public mutating func removeResource(_ id: UUID) { resources.removeAll { $0.id == id }; for index in scenes.indices { scenes[index].resourceIDs.removeAll { $0 == id } } }
    public mutating func recordOpen(_ ids: Set<UUID>, sceneID: UUID?, at date: Date = Date()) {
        for index in resources.indices where ids.contains(resources[index].id) { resources[index].lastOpened = date }
        if !ids.isEmpty, let sceneID, let index = scenes.firstIndex(where: { $0.id == sceneID }) { scenes[index].lastOpened = date }
    }
    public static func decode(_ data: Data) throws -> WorkspaceData { let result = try JSONDecoder().decode(Self.self, from: data); try result.validate(); return result }
    public func encoded() throws -> Data { try validate(); let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; return try encoder.encode(self) }
}

public struct DiskStore {
    public let directory: URL
    public var fileURL: URL { directory.appendingPathComponent("workspace.json") }
    public var backupURL: URL { directory.appendingPathComponent("workspace.previous.json") }
    public init(directory: URL) { self.directory = directory }
    public func load() throws -> WorkspaceData? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try WorkspaceData.decode(Data(contentsOf: fileURL))
    }
    public func save(_ data: WorkspaceData) throws {
        let encoded = try data.encoded()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let old = try Data(contentsOf: fileURL)
            _ = try WorkspaceData.decode(old) // Never overwrite an unreadable store automatically.
            try old.write(to: backupURL, options: .atomic)
        }
        try encoded.write(to: fileURL, options: .atomic)
    }
    public func recoverPrevious() throws -> WorkspaceData {
        let raw = try Data(contentsOf: backupURL)
        let recovered = try WorkspaceData.decode(raw)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let preserved = directory.appendingPathComponent("workspace.recovery-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: fileURL, to: preserved)
        }
        try raw.write(to: fileURL, options: .atomic)
        return recovered
    }
}
