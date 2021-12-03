import Fluent

struct CreateTodo: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("todos")
            .id()
            .field("title", .string, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("todos").delete()
    }
}

struct CreateTradeResult: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(TradeResult.schema)
            .id()
            .field("tradeDate", .date)
            .field("isGood", .bool, .required)
            .field("info", .string)
            .field("userId", .string, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(TradeResult.schema).delete()
    }
}
