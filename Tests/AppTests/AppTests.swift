@testable import App
import XCTVapor

final class AppTests: XCTestCase {
    let userId = UUID(uuidString: "B504832C-5CC4-4DA5-9F9E-BC0D3D880726")!
    
    var encoder: JSONEncoder {
        let coder = JSONEncoder()
        coder.dateEncodingStrategy = .iso8601
        return coder
    }
    
    func testHelloWorld() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)

        try app.test(.GET, "hello", afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Hello, world!")
        })
    }
    
    func testBuyRecommendations() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)
        
        try app.test(.GET, "api/v1/recommendations/AFLT/buy", afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
        })
    }
    
    func testSellRecommendations() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        try configure(app)
        let payload = [
            RecomendationController.SellRecommendationRq(id: UUID().uuidString, ticker: "SBER", date: Date().advanced(by: -3600 * 24 * 3)),
            RecomendationController.SellRecommendationRq(id: UUID().uuidString, ticker: "SBER", date: Date().advanced(by: -3600 * 24 * 4))
        ]
        let encoder = try JSONEncoder().encode(payload)
        
        try app.test(.POST, "api/v1/recommendations/sell", body: ByteBuffer.init(data: encoder), afterResponse: { response in
            XCTAssertEqual(response.status, .ok)
        })
    }
}
