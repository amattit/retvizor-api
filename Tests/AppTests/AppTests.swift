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
}
