//
//  File.swift
//  
//
//  Created by MikhailSeregin on 29.11.2021.
//

import Fluent

// TODO
struct CreateUserInstruments: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(UserInstrument.schema)
            .field("id", .string, .identifier(auto: true))
            .field("ticker", .string, .required)
            .field("tradeDate", .datetime, .required)
            .field("userId", .string, .required)
            .create()
    }
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserInstrument.schema).delete()
    }
}

struct CreateUserInstrumentTip: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(UserInstrumentTip.schema)
            .field("id", .string, .identifier(auto: true))
            .field("create", .datetime, .required)
            .field("tip", .string, .required)
            .field("userInstrumentId", .string, .required, .references(UserInstrument.schema, "id", onDelete: .cascade, onUpdate: .cascade))
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserInstrumentTip.schema).delete()
    }
}

struct CreateRecomendationQuote: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(RecomendationQuote.schema)
            .field("id", .string, .identifier(auto: true))
            .field("create", .datetime, .required)
            .field("ticker", .string, .required)
            .field("tipPeriod", .int)
            .field("buy", .int)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(RecomendationQuote.schema).delete()
    }
}

struct CreateQuotes: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Quotes.schema)
            .field("id", .string, .identifier(auto: true))
            .field("ticker", .string, .required)
            .field("tradeDate", .datetime, .required)
            .field("openPrice", .double)
            .field("closePrice", .double)
            .field("highPrice", .double)
            .field("lowPrice", .double)
            .field("volume", .double)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(Quotes.schema).delete()
    }
}

struct CreateQuotesActuality: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("quotes_actuality")
            .id()
            .field("ticker", .string, .required)
            .field("tradeDate", .datetime, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("quotes_actuality").delete()
    }
}

struct CreateTradeResult: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(TradeResult.schema)
            .id()
            .field("tradeDate", .datetime)
            .field("isGood", .bool, .required)
            .field("info", .string)
            .field("userId", .uuid, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(TradeResult.schema).delete()
    }
}
