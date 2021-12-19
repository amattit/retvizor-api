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
        routes.get("user", ":userId", "journal", use: journal)
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
    
    func journal(req: Request) throws -> EventLoopFuture<[JournalRs]> {
        guard let userId = req.parameters.get("userId")
        else { throw Abort(.badRequest, reason: "Добавьте в запрос параметр userId") }
        
        return Transaction
            .query(on: req.db)
            .filter(\.$user.$id == userId)
            .all()
            .flatMap { transactions in
                Instrument.getSet(for: Array(Set(transactions.map { $0.$instrument.id })), in: req.db).map { instruments in
                    mapJournal(transactions: transactions, instruments: instruments)
                }
            }
    }
    
    func mapJournal(transactions: [Transaction], instruments: [Instrument]) -> [JournalRs] {
        var result = [JournalRs]()
        let buyTransactions = transactions.reduce(into: [Date: [Transaction]]()) { partialResult, item in
            partialResult[item.openDate, default: []].append(item)
        }
        
        for (date, transactions) in buyTransactions {
            let transactionsByTicker = mapByTicker(transactions: transactions)
            for (ticker, transactions) in transactionsByTicker {
                if let instrument = instruments.first(where: { $0.ticker == ticker }), let firstTransaction = transactions.first {
                    let journalItem = JournalRs(
                        id: UUID().uuidString,
                        displayName: instrument.organizationName ?? "",
                        ticker: ticker,
                        imagePath: instrument.imagePath,
                        count: transactions.count,
                        price: Decimal(firstTransaction.openPrice),
                        comment: firstTransaction.comment,
                        date: date,
                        type: .buy
                    )
                    result.append(journalItem)
                }
            }
        }
        
        
        let sellTransactions = transactions.reduce(into: [Date: [Transaction]]()) { partialResult, item in
            if let date = item.closeDate {
                partialResult[date, default: []].append(item)
            }
        }
        
        for (date, transactions) in sellTransactions {
            let transactionsByTicker = mapByTicker(transactions: transactions)
            for (ticker, transactions) in transactionsByTicker {
                if let instrument = instruments.first(where: { $0.ticker == ticker }), let firstTransaction = transactions.first {
                    let journalItem = JournalRs(
                        id: UUID().uuidString,
                        displayName: instrument.organizationName ?? "",
                        ticker: ticker,
                        imagePath: instrument.imagePath,
                        count: transactions.count,
                        price: Decimal(firstTransaction.closePrice ?? 0),
                        comment: firstTransaction.comment,
                        date: date,
                        type: .sell
                    )
                    result.append(journalItem)
                }
            }
        }
        return result.sorted { lhs, rhs in
            lhs.date < rhs.date
        }
    }
    
    func mapByTicker(transactions: [Transaction]) -> [String: [Transaction]] {
        transactions.reduce(into: [String: [Transaction]]()) { partialResult, item in
            partialResult[item.$instrument.id, default: []].append(item)
        }
    }
}

struct JournalRs: Content {
    var id: String // сгенерированный id
    let displayName: String
    let ticker: String
    let imagePath: String?
    let count: Int
    let price: Decimal
    let comment: String?
    let date: Date
    let type: TransactionType; enum TransactionType: String, Content {
        case buy, sell
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
