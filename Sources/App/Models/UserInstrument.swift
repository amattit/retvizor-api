//
//  File.swift
//  
//
//  Created by 16997598 on 18.11.2021.
//

import Fluent
import Vapor

final class UserInstrument: Model, Content {
    static let schema = "user_instrument"
    
    @ID(custom: "id")
    var id: String?
    
    @Parent(key: "ticker")
    var ticker: Instrument
    
    @Field(key: "tradeDate")
    var date: Date?
    
    @Parent(key: "userId")
    var user: User
    
    @Children(for: \.$userInstrument)
    var transactions: [Transaction]
    
    init() {
        
    }
    
    init(with dto: CreateInstrumentRequest) {
        self.id = UUID().uuidString
        self.$ticker.id = dto.ticker
        self.$user.id = dto.userId.uuidString
        self.date = dto.date
    }
}

final class UserInstrumentTip: Model, Content {
    static let schema = "user_instrument_tip"
    
    @ID(custom: "id")
    var id: String?
    
    @Timestamp(key: "create", on: .create)
    var date: Date?
    
    @Field(key: "tip")
    var tip: String
    
    @Field(key: "userInstrumentId")
    var instrumentId: String
}

final class RecomendationQuote: Model, Content {
    static let schema = "recomendation_quotes"
        
    @ID(custom: "id")
    var id: String?
    
    @Field(key: "create")
    var date: Date?
    
    @Field(key: "tipPeriod")
    var tipPeriod: Int
    
    @Field(key: "ticker")
    var ticker: String
    
    @Field(key: "buy")
    var buy: Int
    
    init() {}
}

final class Quotes: Model, Content, Equatable {
    static var schema = "quotes"

    static func == (lhs: Quotes, rhs: Quotes) -> Bool {
        lhs.openPrice == rhs.openPrice
        && lhs.date == rhs.date
        && lhs.closePrice == rhs.closePrice
        && lhs.ticker == rhs.ticker
    }
    
    
    @ID(custom: "id")
    var id: String?
    
    @Field(key: "tradeDate")
    var date: Date?
    
    @Field(key: "openPrice")
    var openPrice: Double
    
    @Field(key: "closePrice")
    var closePrice: Double
    
    @Field(key: "ticker")
    var ticker: String
    
    @Field(key: "volume")
    var volume: Double?
    
    @Field(key: "lowPrice")
    var lowPrice: Double?
    
    @Field(key: "highPrice")
    var highPrice: Double?
    
    init() {}
    
    static func getLastQuote(for ticker: String, on db: Database) -> EventLoopFuture<Quotes> {
        Quotes
            .query(on: db)
            .filter(\.$ticker == ticker)
            .sort(\.$date, .descending)
            .first()
            .unwrap(or: Abort(.notFound))
    }
    
    static func getLastQuote(for tickers: [String], on req: Request) -> EventLoopFuture<[Quotes]> {
        tickers.map {
            Quotes.getLastQuote(for: $0, on: req.db)
        }
        .flatten(on: req.eventLoop)
    }
}

extension Quotes: CustomStringConvertible {
    var description: String {
        """
        id: \(id ?? ""),
        ticker: \(ticker),
        date: \(date ?? "")
        """
    }
}

final class TradeResult: Model, Content {
    static let schema = "trade_result"
    
    @ID(custom: "id")
    var id: String?
    
    @Field(key: "tradeDate")
    var date: Date?
    
    @Field(key: "isGood")
    var isGood: Bool
    
    @Field(key: "info")
    var info: String?
    
    @Field(key: "userId")
    var userId: String
    
    init() {}
    
    init(id: UUID? = nil, date: Date, isGood: Bool, info: String?, userId: String) {
        self.id = id?.uuidString
        self.date = date
        self.isGood = isGood
        self.info = info
        self.userId = userId
    }
}

