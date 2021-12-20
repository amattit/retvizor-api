//
//  File.swift
//  
//
//  Created by Михаил Серегин on 08.12.2021.
//

import Vapor
import Fluent

// MARK: Controller
struct InstrumentController: RouteCollection {
    static var stocks: [StockRs] = []
    
    func boot(routes: RoutesBuilder) throws {
        let instrument = routes.grouped("admin", "instruments")
        
        instrument.get(use: fetchInstruments)
        instrument.patch(use: updateInstrument)
        instrument.post(use: createInstrument)
        instrument.post("batch", use: batchCreate)
        instrument.delete(":id", use: delete)
        
        // public
        routes.get("api", "v1", "instruments", use: fetchInstrument)
    }
}

// MARK: - fetch
extension InstrumentController {
    func fetchInstruments(req: Request) throws -> EventLoopFuture<[Instrument]> {
        Instrument.query(on: req.db).all()
    }
}

// MARK: - update
extension InstrumentController {
    func updateInstrument(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let dto = try req.content.decode(Instrument.self)
        return Instrument.find(dto.id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { instrument in
                instrument
                    .update(from: dto)
                    .save(on: req.db)
                    .transform(to: HTTPStatus.ok)
            }
    }
}

//MARK: - create
extension InstrumentController {
    func createInstrument(req: Request) throws -> EventLoopFuture<Instrument> {
        let dto = try req.content.decode(Instrument.self)
        let instrument = Instrument(dto: dto)
        let response = instrument
            .save(on: req.db)
            .map {
                return instrument
            }
        
        return response
    }
    
    func batchCreate(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let dto = try req.content.decode([Instrument].self).map {
            Instrument(dto: $0)
        }
        return dto.create(on: req.db)
            .transform(to: HTTPStatus.ok)
    }
}

//MARK: delete
extension InstrumentController {
    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let id = req.parameters.get("id")
        else { throw Abort(.badRequest, reason: "Должен быть path параметр id инструмента") }
        return Instrument.find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap {
                $0
                    .delete(on: req.db)
                    .transform(to: HTTPStatus.ok)
            }
    }
}

// MARK: Public API
extension InstrumentController {
    func fetchStocks(_ req: Request) throws  -> EventLoopFuture<[StockRs]> {
        if Self.stocks.isEmpty {
            let response = Instrument
                .query(on: req.db)
                .all()
                .map { item -> [StockRs] in
                    Self.stocks = item.map {
                        StockRs(id: $0.id ?? "", ticker: $0.ticker, displayName: $0.organizationName, image: $0.imagePath)
                    }
                    return Self.stocks
                }
            
            return response
        } else {
            return req.eventLoop.makeSucceededFuture(Self.stocks)
        }
    }
    
    func fetchInstrument(_ req: Request) throws -> EventLoopFuture<StockDetailsRs> {
        let dto = try req.query.decode(StockRq.self)
        
        return Instrument
            .query(on: req.db)
            .filter(\.$ticker == dto.ticker)
            .first()
            .unwrap(or: Abort(.notFound, reason: "Инструмент с тикером \(dto.ticker) не найден"))
            .flatMap { instrument -> EventLoopFuture<StockDetailsRs> in
                if dto.userId == nil {
                    let response =  StockDetailsRs(
                        info: StockRs(
                            id: instrument.id ?? "",
                            ticker: instrument.ticker,
                            displayName: instrument.organizationName ?? "",
                            image: instrument.imagePath
                        ),
                        journal: []
                    )
                    return req.eventLoop.future(response)
                } else {
                    return Transaction
                        .query(on: req.db)
                        .filter(\.$user.$id == dto.userId!)
                        .filter(\.$instrument.$id == dto.ticker)
                        .filter(\.$closeDate == nil)
                        .all()
                        .flatMap { transactions in
                            Instrument.getSet(for: Array(Set(transactions.map { $0.$instrument.id })), in: req.db).map { instruments in
                                return StockDetailsRs(
                                    info: StockRs(
                                        id: instrument.id ?? "",
                                        ticker: instrument.ticker,
                                        displayName: instrument.organizationName ?? "",
                                        image: instrument.imagePath
                                    ),
                                    journal: mapJournal(transactions: transactions, instruments: instruments)
                                )
                            }
                        }
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
                        comment: firstTransaction.sellComment,
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

struct StockRq: Content {
    let userId: String?
    let ticker: String
}

struct StockDetailsRs: Content {
    let info: StockRs
    let journal: [JournalRs]
}

// MARK: - Models
final class Instrument: Model, Content {
    static var schema = "instrument"
    
    @ID(custom: "id")
    var id: String?
    
    @Field(key: "ticker")
    var ticker: String
    
    @OptionalField(key: "description")
    var information: String?
    
    @OptionalField(key: "branch")
    var branch: String?
    
    @OptionalField(key: "esgCategory")
    var esgCategory: String?
    
    @OptionalField(key: "imagePath")
    var imagePath: String?
    
    @OptionalField(key: "rating")
    var rating: String?
    
    @OptionalField(key: "name")
    var organizationName: String?
    
    @OptionalField(key: "riskCategory")
    var riskCategory: String?
    
    @Children(for: \.$ticker)
    var userInstruments: [UserInstrument]
    
    // TODO: Пока непонятно, понадобится или нет
    @Children(for: \.$instrument)
    var transactions: [Transaction]
    
    init() {}
    
    init(dto: Instrument) {
        id = UUID().uuidString
        
        ticker = dto.ticker
        
        if let item = dto.branch {
            branch = item
        }
        
        if let item = dto.information {
            information = item
        }
        
        if let item = dto.esgCategory {
            esgCategory = item
        }
        
        if let item = dto.imagePath {
            imagePath = item
        }
        
        if let item = dto.organizationName {
            organizationName = item
        }
        
        if let item = dto.rating {
            rating = item
        }
        
        if let item = dto.riskCategory {
            riskCategory = item
        }
    }
    
    func update(from dto: Instrument) -> Self {
        ticker = dto.ticker
        
        if let item = dto.branch {
            branch = item
        }
        
        if let item = dto.information {
            information = item
        }
        
        if let item = dto.esgCategory {
            esgCategory = item
        }
        
        if let item = dto.imagePath {
            imagePath = item
        }
        
        if let item = dto.organizationName {
            organizationName = item
        }
        
        if let item = dto.rating {
            rating = item
        }
        
        if let item = dto.riskCategory {
            riskCategory = item
        }
        return self
    }
}

struct StockRs: Content {
    let id, ticker: String
    let displayName, image: String?
}

extension Instrument {
    static func getSet(for tickers: [String], in db: Database) -> EventLoopFuture<[Instrument]> {
        Instrument
            .query(on: db)
            .filter(\.$ticker ~~ tickers)
            .all()
    }
}
