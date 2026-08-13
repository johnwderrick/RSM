import XCTest
@testable import Retro_Season_Manager

/// Constructs a `GameStore` safely.
///
/// Constructing `GameStore()` directly inside a synchronous `@MainActor`
/// test method reliably crashes on this toolchain (a malloc double-free
/// deep inside `libswift_Concurrency`'s `TaskLocal` machinery — see
/// memory/rsm_infra_and_known_issues.md). Routing construction through an
/// actual `Task { @MainActor in ... }` hop avoids it entirely, repeatably,
/// including through a full `newGame()` call. Use this everywhere a test
/// needs a live instance instead of constructing one inline.
@MainActor
func makeTestStore() async -> GameStore {
    await Task { @MainActor in GameStore() }.value
}
