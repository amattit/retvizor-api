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
            .field("TICKER", .string, .required)
            .field("TRADEDATE", .date, .required)
            .field("USER_ID", .string, .required)
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
            .field("CREATION_DATE", .date, .required)
            .field("TIP", .string, .required)
            .field("USER_INSTRUMENT_ID", .string, .required)
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
            .field("CREATION_DATE", .date, .required)
            .field("TICKER", .string, .required)
            .field("TIP_PERIOD", .int)
            .field("BUY", .int)
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
            .field("TICKER", .string, .required)
            .field("TRADEDATE", .date, .required)
            .field("OPEN_PRICE", .double)
            .field("CLOSE_PRICE", .double)
            .field("HIGH_PRICE", .double)
            .field("LOW_PRICE", .double)
            .field("VOLUME", .double)
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
            .field("TICKER", .string, .required)
            .field("TRADEDATE", .date, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("quotes_actuality").delete()
    }
}
