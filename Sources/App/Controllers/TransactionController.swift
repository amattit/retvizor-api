//
//  File.swift
//  
//
//  Created by Михаил Серегин on 17.12.2021.
//

import Vapor

struct TransactionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("user", ":userId", "transactions", use: index)
    }
}

extension TransactionController {
    func index(req: Request) throws -> EventLoopFuture<[TransactionsRs]> {
        guard let userId = req.parameters.get("userId")
        else { throw Abort(.badRequest, reason: "Добавьте в запрос параметр userId") }
        
        return Transaction
            .query(on: req.db)
            .filter(\.$user.$id == userId)
            .filter(\.$closeDate == nil)
            .sort(\.$openDate)
            .all()
            .map {
                $0.map {
                    TransactionsRs(
                        id: $0.id ?? "",
                        openPrice: $0.openPrice,
                        closePrice: $0.closePrice,
                        closeDate: $0.closeDate,
                        openDate: $0.openDate,
                        comment: $0.comment,
                        userId: $0.$user.id,
                        userInstrument: $0.$userInstrument.id,
                        ticker: $0.$instrument.id
                    )
                }
            }
    }
}

struct TransactionsRs: Content {
    var id: String
    var openPrice: Double
    var closePrice: Double?
    var closeDate: Date?
    var openDate: Date
    var comment: String?
    var userId: String
    var userInstrument: String
    var ticker: String
}

import Fluent
final class Transaction: Model, Content {
    static var schema = "transactions"
    @ID(custom: "id")
    var id: String?
    
    @Field(key: "openPrice")
    var openPrice: Double
    
    @Field(key: "closePrice")
    var closePrice: Double?
    
    @Field(key: "closeDate")
    var closeDate: Date?
    
    @Field(key: "openDate")
    var openDate: Date
    
    @Field(key: "comment")
    var comment: String?
    
    @Parent(key: "ticker")
    var instrument: Instrument
    
    @Parent(key: "userId")
    var user: User
    
    @Parent(key: "userInstrumentId")
    var userInstrument: UserInstrument
    
    init() {}
    
    init(
        id: String? = UUID().uuidString,
        openPrice: Double,
        openDate: Date = Date(),
        comment: String? = "",
        ticker: String,
        userId: String,
        userInstrumentId: String
    ) {
        self.id = id
        self.openPrice = openPrice
        self.openDate = openDate
        self.comment = comment
        self.$instrument.id = ticker
        self.$user.id = userId
        self.$userInstrument.id = userInstrumentId
    }
}
