import Foundation
import DeskCore

final class WorkspaceTests {
    private var directory: URL!
    func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("shixu-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    func tearDownWithError() throws { try? FileManager.default.removeItem(at: directory) }

    func testWebsiteAddressesNormalizeAndRejectExecutableSchemes() throws {
        try expectEqual(try Resource.websiteURL(" github.com/openai ").absoluteString, "https://github.com/openai")
        try expectEqual(try Resource.websiteURL("https://example.com/a?b=1&c=2").query, "b=1&c=2")
        for invalid in ["", "javascript:alert(1)", "file:///tmp/a", "ftp://example.com", "https://", "a b.com", "https://person:secret@example.com"] {
            try expectThrows(try Resource.websiteURL(invalid), invalid)
        }
    }
    func testSceneRoundTripPreservesOrderAndChineseNames() throws {
        var data = WorkspaceData.starter()
        let file = Resource(name: "阅读笔记.txt", kind: .file, location: directory.appendingPathComponent("阅读笔记.txt").path)
        data.upsert(file, into: data.scenes[0].id)
        let disk = DiskStore(directory: directory)
        try disk.save(data)
        let reloaded = try unwrap(disk.load())
        try expectEqual(reloaded, data)
        try expectEqual(reloaded.resources(in: reloaded.scenes[0]).last?.name, "阅读笔记.txt")
    }
    func testAttachingResourceTwiceDoesNotDuplicateIt() throws {
        var data = WorkspaceData.starter()
        let resource = data.resources[0], sceneID = data.scenes[0].id
        data.upsert(resource, into: sceneID); data.upsert(resource, into: sceneID)
        try expectEqual(data.resources.count, 3)
        try expectEqual(data.scenes[0].resourceIDs.filter { $0 == resource.id }.count, 1)
        try data.validate()
    }
    func testRemovalCleansSceneReferencesWithoutDeletingRealFile() throws {
        let file = directory.appendingPathComponent("keep.txt"); try Data("keep".utf8).write(to: file)
        var data = WorkspaceData.starter()
        let resource = Resource(name: "keep", kind: .file, location: file.path)
        data.upsert(resource, into: data.scenes[0].id)
        data.removeResource(resource.id)
        try expectFalse(data.scenes[0].resourceIDs.contains(resource.id))
        try expectTrue(FileManager.default.fileExists(atPath: file.path))
        try data.validate()
    }
    func testBackupRecoversPreviousVersionAndPreservesDamagedFile() throws {
        let disk = DiskStore(directory: directory)
        let first = WorkspaceData.starter()
        try disk.save(first)
        var second = first; second.scenes[0].name = "更新后的场景"; try disk.save(second)
        let damaged = Data("broken json".utf8); try damaged.write(to: disk.fileURL)
        try expectThrows(try disk.load())
        try expectEqual(try disk.recoverPrevious(), first)
        try expectEqual(try disk.load(), first)
        let kept = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("workspace.recovery-") }
        try expectEqual(kept.count, 1)
        try expectEqual(try Data(contentsOf: kept[0]), damaged)
    }
    func testCorruptStoreIsNeverOverwrittenByOrdinarySave() throws {
        let disk = DiskStore(directory: directory), original = Data("not JSON".utf8)
        try original.write(to: disk.fileURL)
        try expectThrows(try disk.save(.starter()))
        try expectEqual(try Data(contentsOf: disk.fileURL), original)
    }
    func testRejectsBrokenImportsAndFutureSchema() throws {
        var data = WorkspaceData.starter()
        data.scenes[0].resourceIDs.append(UUID())
        try expectThrows(try WorkspaceData.decode(JSONEncoder().encode(data)))
        data = .starter(); data.version = 2
        try expectThrows(try WorkspaceData.decode(JSONEncoder().encode(data)))
        data = .starter(); data.resources.append(data.resources[0])
        try expectThrows(try data.validate())
    }
    func testMissingFileGivesActionableError() throws {
        let resource = Resource(name: "已移动文件", kind: .file, location: directory.appendingPathComponent("missing.txt").path)
        try expectThrows(try resource.resolvedURL()) { error in try expectTrue(error.localizedDescription.contains("重新选择")) }
    }
    func testBookmarksAndPathFallbackResolveSelectedFiles() throws {
        let file = directory.appendingPathComponent("资料.txt"); try Data("test".utf8).write(to: file)
        let bookmark = try file.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        let bookmarked = Resource(name: "资料", kind: .file, location: file.path, bookmark: bookmark)
        try expectEqual(try bookmarked.resolvedURL().standardizedFileURL.path, file.standardizedFileURL.path)
        let fallback = Resource(name: "资料", kind: .file, location: file.path, bookmark: Data("invalid".utf8))
        try expectEqual(try fallback.resolvedURL().path, file.path)
    }
    func testSearchMatchesNamePathAndAllTokens() throws {
        let file = Resource(name: "跑步账号分析.pdf", kind: .file, location: "/Users/demo/公众号素材/跑步账号分析.pdf")
        try expectTrue(file.matches("跑步 pdf"))
        try expectTrue(file.matches("公众号"))
        try expectFalse(file.matches("跑步 视频"))
        try expectTrue(Resource(name: "GitHub", kind: .website, location: "https://github.com").matches("GITHUB"))
    }
    func testOnlySuccessfulOpensEnterRecentList() throws {
        var data = WorkspaceData.starter(); let time = Date(timeIntervalSince1970: 100)
        data.recordOpen([data.resources[0].id], sceneID: data.scenes[0].id, at: time)
        try expectEqual(data.resources[0].lastOpened, time)
        try expectNil(data.resources[1].lastOpened)
        try expectEqual(data.scenes[0].lastOpened, time)
        data.recordOpen([], sceneID: data.scenes[1].id, at: time)
        try expectNil(data.scenes[1].lastOpened)
    }
    func testInvalidSaveLeavesCurrentAndBackupUntouched() throws {
        let disk = DiskStore(directory: directory); let good = WorkspaceData.starter(); try disk.save(good)
        var bad = good; bad.scenes[0].name = "  "
        try expectThrows(try disk.save(bad))
        try expectEqual(try disk.load(), good)
        try expectFalse(FileManager.default.fileExists(atPath: disk.backupURL.path))
    }
}
