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
            .id()
            .field("ticker", .string, .required)
            .field("tradeDate", .date, .required)
            .field("userId", .uuid, .required)
            .create()
    }
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserInstrument.schema).delete()
    }
}

struct CreateUserInstrumentTip: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(UserInstrumentTip.schema)
            .id()
            .field("create", .date, .required)
            .field("tip", .string, .required)
            .field("userInstrumentId", .uuid, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(UserInstrumentTip.schema).delete()
    }
}

struct CreateRecomendationQuote: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(RecomendationQuote.schema)
            .id()
            .field("create", .date, .required)
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
            .id()
            .field("ticker", .string, .required)
            .field("tradeDate", .date, .required)
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
            .field("tradeDate", .date, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("quotes_actuality").delete()
    }
}
