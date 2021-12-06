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
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "ticker")
    var ticker: String
    
    @Field(key: "tradeDate")
    var date: Date?
    
    @Field(key: "userId")
    var userId: UUID
    
    init() {
        
    }
    
    init(with dto: CreateInstrumentRequest) {
        self.id = UUID()
        self.ticker = dto.ticker
        self.userId = dto.userId
        self.date = dto.date
    }
}

final class UserInstrumentTip: Model, Content {
    static let schema = "user_instrument_tip"
    
    @ID(key: .id)
    var id: UUID?
    
    @Timestamp(key: "create", on: .create)
    var date: Date?
    
    @Field(key: "tip")
    var tip: String
    
    @Field(key: "userInstrumentId")
    var instrumentId: UUID
}

final class RecomendationQuote: Model, Content {
    static let schema = "recomendation_quotes"
        
    @ID(key: .id)
    var id: UUID?
    
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
    
    init() {}
}

final class TradeResult: Model, Content {
    static let schema = "trade_result"
    
    @ID(key: .id)
    var id: UUID?
    
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
        self.id = id
        self.date = date
        self.isGood = isGood
        self.info = info
        self.userId = userId
    }
}
