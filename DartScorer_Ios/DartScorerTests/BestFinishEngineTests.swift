import XCTest
@testable import DartScorer

final class BestFinishEngineTests: XCTestCase {
    private var engine: BestFinishEngine!

    override func setUp() {
        super.setUp()
        engine = BestFinishEngine()
    }

    func test85ReturnsT15D20() {
        let route = engine.getBestFinish(for: 85, dartsRemaining: 2)
        XCTAssertEqual(engine.routeTokens(route), ["T15", "D20"])
    }

    func test101ReturnsT20S9D16() {
        let route = engine.getBestFinish(for: 101, dartsRemaining: 3)
        XCTAssertEqual(engine.routeTokens(route), ["T20", "S9", "D16"])
    }

    func testMissRecoveryFrom101AfterSingle20GoesTo81Route() {
        let store = CheckoutAssistantStore()
        store.startLeg(startingAt: 101)
        XCTAssertEqual(engine.routeTokens(store.suggestion ?? .init(darts: [], label: "", rationale: "")), ["T20", "S9", "D16"])

        store.recordThrow(pointsHit: 20)

        XCTAssertEqual(store.currentScore, 81)
        XCTAssertEqual(store.dartsRemaining, 2)
        XCTAssertEqual(engine.routeTokens(store.suggestion ?? .init(darts: [], label: "", rationale: "")), ["T19", "D12"])
    }

    func test195SetupSuggests25ToLeave170() {
        let route = engine.getBestFinish(for: 195, dartsRemaining: 3)
        XCTAssertEqual(engine.routeTokens(route), ["25"])
        XCTAssertEqual(route.label, "Setup")
    }

    func test169SetupSuggestsS9ToLeave160() {
        let route = engine.getBestFinish(for: 169, dartsRemaining: 3)
        XCTAssertEqual(engine.routeTokens(route), ["S9"])
        XCTAssertEqual(route.label, "Setup")
    }

    func test82ReturnsBullD16() {
        let route = engine.getBestFinish(for: 82, dartsRemaining: 2)
        XCTAssertEqual(engine.routeTokens(route), ["Bull", "D16"])
    }

    func test51PrefersSingle11Double20OverTrebleRoute() {
        let route = engine.getBestFinish(for: 51, dartsRemaining: 2)
        XCTAssertEqual(engine.routeTokens(route), ["S11", "D20"])
    }

    func test50ReturnsBull() {
        let route = engine.getBestFinish(for: 50, dartsRemaining: 3)
        XCTAssertEqual(engine.routeTokens(route), ["Bull"])
    }

    func testSuggestedCheckoutRoutesEndOnDoubleOrBull() {
        let sampleScores = [2, 32, 40, 44, 52, 61, 70, 82, 85, 90, 101, 132, 170]
        for score in sampleScores {
            let route = engine.getBestFinish(for: score, dartsRemaining: 3)
            let total = route.darts.reduce(0) { $0 + $1.total }
            if total == score, let last = route.darts.last {
                XCTAssertTrue(engine.isFinishingTarget(last), "Expected finishing dart for score \(score)")
            }
        }
    }
}
