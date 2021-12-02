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
    
    @ID(custom: "ID")
    var id: String?
    
    @Field(key: "TICKER")
    var ticker: String
    
    @Field(key: "TRADEDATE")
    var date: Date?
    
    @Field(key: "USER_ID")
    var userId: String
    
    init() {
        
    }
    
    init(with dto: CreateInstrumentRequest) {
        self.id = UUID().uuidString
        self.ticker = dto.ticker
        self.userId = dto.userId
        self.date = dto.date
    }
}

final class UserInstrumentTip: Model, Content {
    static let schema = "user_instrument_tip"
    
    @ID(custom: "ID")
    var id: String?
    
    @Timestamp(key: "CREATION_DATE", on: .create)
    var date: Date?
    
    @Field(key: "TIP")
    var tip: String
    
    @Field(key: "USER_INSTRUMENT_ID")
    var instrumentId: String
}

final class RecomendationQuote: Model, Content {
    static let schema = "recomendation_quotes"
    
    @ID(custom: "ID")
    var id: String?
    
    @Field(key: "CREATION_DATE")
    var date: Date?
    
    @Field(key: "TIP_PERIOD")
    var tipPeriod: Int
    
    @Field(key: "TICKER")
    var ticker: String
    
    @Field(key: "BUY")
    var buy: Int
    
    init() {}
}

final class Quotes: Model, Content, Equatable {
    static func == (lhs: Quotes, rhs: Quotes) -> Bool {
        lhs.openPrice == rhs.openPrice
        && lhs.date == rhs.date
        && lhs.closePrice == rhs.closePrice
        && lhs.ticker == rhs.ticker
    }
    
    
    @ID(custom: "ID")
    var id: String?
    
    static var schema = "quotes"
    
    @Field(key: "TRADEDATE")
    var date: Date?
    
    @Field(key: "OPEN_PRICE")
    var openPrice: Double
    
    @Field(key: "CLOSE_PRICE")
    var closePrice: Double
    
    @Field(key: "TICKER")
    var ticker: String
    
    init() {}
}
