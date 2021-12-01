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
            .field("TRADE_DATE", .date)
            .field("IS_GOOD", .bool, .required)
            .field("INFO", .string)
            .field("USER_ID", .string, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(TradeResult.schema).delete()
    }
}
