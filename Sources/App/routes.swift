import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return req.view.render("index", ["title": "Hello Vapor!"])
    }

    app.get("hello") { req -> String in
        return "Hello, world!"
    }

//    try app.register(collection: TodoController())
    try app.register(collection: UserInstrumentController())
    try app.register(collection: RecomendationController())
    try app.register(collection: TradeResultController())
    try app.register(collection: HealthCheckController())
    try app.register(collection: InstrumentController())
    try app.register(collection: CandlesController())
    try app.register(collection: PopularQuotesController())
}
