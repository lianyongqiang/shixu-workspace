import Foundation

struct CheckFailure: Error, CustomStringConvertible { let description: String }
func expectTrue(_ value: @autoclosure () throws -> Bool, _ message: String = "expected true", file: StaticString = #filePath, line: UInt = #line) throws { if try !value() { throw CheckFailure(description: "\(file):\(line) \(message)") } }
func expectFalse(_ value: @autoclosure () throws -> Bool, file: StaticString = #filePath, line: UInt = #line) throws { try expectTrue(!value(), "expected false", file: file, line: line) }
func expectEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) throws { let left = try a(), right = try b(); if left != right { throw CheckFailure(description: "\(file):\(line) values differ: \(left) != \(right)") } }
func expectNil<T>(_ value: @autoclosure () -> T?, file: StaticString = #filePath, line: UInt = #line) throws { try expectTrue(value() == nil, "expected nil", file: file, line: line) }
func unwrap<T>(_ value: T?) throws -> T { guard let value else { throw CheckFailure(description: "unexpected nil") }; return value }
func expectThrows<T>(_ body: @autoclosure () throws -> T, _ message: String = "expected failure", handler: ((Error) throws -> Void)? = nil, file: StaticString = #filePath, line: UInt = #line) throws {
    do { _ = try body() } catch { try handler?(error); return }
    throw CheckFailure(description: "\(file):\(line) \(message)")
}

let tests = WorkspaceTests()
let checks: [(String, () throws -> Void)] = [
    ("website validation", tests.testWebsiteAddressesNormalizeAndRejectExecutableSchemes),
    ("persistence and Chinese paths", tests.testSceneRoundTripPreservesOrderAndChineseNames),
    ("duplicate attachment", tests.testAttachingResourceTwiceDoesNotDuplicateIt),
    ("safe removal", tests.testRemovalCleansSceneReferencesWithoutDeletingRealFile),
    ("backup recovery", tests.testBackupRecoversPreviousVersionAndPreservesDamagedFile),
    ("corruption protection", tests.testCorruptStoreIsNeverOverwrittenByOrdinarySave),
    ("import validation", tests.testRejectsBrokenImportsAndFutureSchema),
    ("missing files", tests.testMissingFileGivesActionableError),
    ("bookmarks and fallback", tests.testBookmarksAndPathFallbackResolveSelectedFiles),
    ("search", tests.testSearchMatchesNamePathAndAllTokens),
    ("successful-open history", tests.testOnlySuccessfulOpensEnterRecentList),
    ("failed-save preservation", tests.testInvalidSaveLeavesCurrentAndBackupUntouched)
]
var failures = 0
for (name, check) in checks {
    do { try tests.setUpWithError(); try check(); print("PASS \(name)") }
    catch { failures += 1; print("FAIL \(name): \(error)") }
    try? tests.tearDownWithError()
}
print("\(checks.count - failures)/\(checks.count) checks passed")
if failures != 0 { exit(1) }
