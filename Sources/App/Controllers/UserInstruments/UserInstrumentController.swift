//
//  File.swift
//  
//
//  Created by 16997598 on 19.11.2021.
//

import Vapor
import FluentKit

/// #API
/// #Свои инструменты
/// [GET] /api/v1/user/:id/instruments/ - список своих инструментов
/// [GET] /api/v1/user/instruments/:id
/// [POST] /api/v1/user/instruments -  добавить свой инструмент
/// [DELETE] /api/v1/user/instruments/:id - удалить свой инструмент
///
/// #Рекоментации
/// [GET] /api/v1/recomendations/stocks - Рекомендуемые к покупке
///
/// #Список инструментов
/// [GET] /api/v1/instruments
struct UserInstrumentController: RouteCollection {
    let mapper = Mapper()
    func boot(routes: RoutesBuilder) throws {
        
        let i = routes.grouped("api", "v1", "instruments")
        i.get(use: InstrumentController().fetchStocks)
        
        let instruments = routes.grouped("api", "v1", "user")
        
        let v2 = routes.grouped("api", "v2", "user")
        
        v2.group(":id") { api in
            api.grouped("instruments").get(use: indexV2)
        }
        
        instruments.group(":id") { api in
            api.grouped("instruments").get(use: index)
        }
        // Получить свои инструменты
        instruments.group("instruments") { instrument in
            instrument.grouped(":id").delete(use: delete)
            instrument.grouped(":id").get(use: details)
        }
        
        instruments.grouped("instruments").post(use: create)
        
        routes.post("api", "v1", "instruments", "sell", use: sell)
    }
}

extension UserInstrumentController {
    /// Список своих инструментов
    func index(req: Request) throws -> EventLoopFuture<[StockItemRs]> {
        let userId = req.parameters.get("id")
        
        return User
            .getTransactions(for: userId, on: req.db)
            .map { transactions -> EventLoopFuture<[StockItemRs]> in
            
            let tickers = transactions.map { $0.$instrument.id }
            let instruments = Instrument.getSet(for: tickers, in: req.db)
            return instruments.map {
                mapper.mapStockRs(from: $0, and: transactions)
            }
        }
            .flatMap { $0 }
    }
    
    
    
    func indexV2(req: Request) throws -> EventLoopFuture<[GroupedUserInstrumentsRs]> {
        guard let userId = req.parameters.get("id") else {
            throw Abort(.notFound)
        }
        
        return try InstrumentController().fetchStocks(req).flatMap { stocks in
            return UserInstrument
                .query(on: req.db)
                .filter(\.$user.$id, .equal, userId)
                .all()
                .map {
                    $0.reduce(into: [String:[UserInstrument]]()) { partialResult, instrument in
                        partialResult[instrument.$ticker.id, default: []].append(instrument)
                    }
                    .reduce(into: [GroupedUserInstrumentsRs]()) { partialResult, keyValue in
                        let stock = stocks.first(where: { $0.ticker == keyValue.key})
                        let items = keyValue.value.map {
                            MyStockRs(id: $0.id ?? "", ticker:$0.$ticker.id, displayName: stock?.displayName ?? "Неизвестное название", image: stock?.image ?? "", date: $0.date ?? Date())
                        }
                        partialResult.append(GroupedUserInstrumentsRs(id: UUID().uuidString, ticker: keyValue.key, instruments: items))
                    }
                    .sorted { lhs, rhs in
                        lhs.ticker < rhs.ticker
                    }
                }
            
        }
    }
    
    /// Добавление нового инструмента
    func create(req: Request) throws -> EventLoopFuture<MyStockRs> {
        let dto = try req.content.decode(CreateInstrumentRequest.self)
        let instrument = UserInstrument(with: dto)
        
        let response = instrument.save(on: req.db)
            .map { _ -> MyStockRs in
                if let count = dto.count {
                    let instruments = (1...count).map { _ in
                        Transaction(
                            openPrice: dto.price ?? 0,
                            openDate: dto.date,
                            comment: dto.comment,
                            ticker: dto.ticker,
                            userId: dto.userId.uuidString,
                            userInstrumentId: instrument.id ?? ""
                        )
                    }
                    _ = instruments.create(on: req.db)
                }
                let stock = InstrumentController.stocks.first(where: { $0.ticker == instrument.$ticker.id})
                return MyStockRs(id: instrument.id ?? "", ticker: instrument.$ticker.id, displayName: stock?.displayName ?? "Неизвестная компания", image: stock?.image ?? "", date: instrument.date ?? Date()) }
        return req.client.get("https://retvizor.herokuapp.com/user_instruments/\(instrument.id ?? "")").tryFlatMap { data in
            req.logger.info("call python server on https://retvizor.herokuapp.com/user_instruments/\(instrument.id ?? "")")
            req.logger.info("request returned status: \(data.status.code.description)")
            return response
        }
    }
    
    /// Удаление своего инструмента
    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let id = req.parameters.get("id") else { throw Abort(.badRequest) }
        
        return UserInstrument.find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { $0.delete(on: req.db)}
            .transform(to: .ok)
    }
    
    func details(req: Request) throws -> EventLoopFuture<InstrumentWithTipResponse> {
        guard let instrumentId = req.parameters.get("id") else { throw Abort(.badRequest) }
        
        return req.client.get("https://retvizor.herokuapp.com/user_instruments/\(instrumentId)", headers: .init([("Content-Type", "application/json")])).tryFlatMap { data in
            req.logger.info("call python server on https://retvizor.herokuapp.com/user_instruments/\(instrumentId)")
            req.logger.info("request returned status: \(data.status.code.description)")
            if data.status.code == 200 {
                if let data = try? data.content.decode(InstrumentRecomendationRs.self) {
                    return try getDetails(req: req, instrumentId: instrumentId, recommendation: data)
                }
            }
            return try getDetails(req: req, instrumentId: instrumentId, recommendation: nil)
        }
    }
    
    private func getDetails(req: Request, instrumentId: String, recommendation: InstrumentRecomendationRs?) throws -> EventLoopFuture<InstrumentWithTipResponse> {
        return UserInstrument
            .find(instrumentId, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { instrument in
                Quotes
                    .query(on: req.db)
                    .group(.and) { group in
                        group
                            .filter(\.$ticker, .equal, instrument.$ticker.id)
                            .filter(\.$date, .greaterThanOrEqual, instrument.date?.startOfDay ?? Date())
                            .filter(\.$date, .lessThanOrEqual, Date())
                    }
                    .sort(\.$date)
                    .all()
                    .map { quotes in
                        let first = quotes.first?.closePrice ?? 0
                        let summRevenue = quotes
                            .reduce(into: [Double]()) { partialResult, item in
                                partialResult.append((item.closePrice / first - 1) * 100)
                            }
                            .last
                        let sr = summRevenue ?? 0
                        let rr = recommendation?.requiredReturn ?? 0
                        let requiredReturnRecommendation = sr < rr
                        // TODO: доделать
                        ? "акция имеет потенциал роста за текущий период с \(instrument.date?.shortFormat ?? "") в размере \(rr) - \(sr)%"
                        : ""
                        
                        return InstrumentWithTipResponse(
                            id: instrument.id ?? "",
                            ticker: instrument.$ticker.id,
                            date: instrument.date ?? Date(),
                            tips: [
                                .init(date: Date(), description: recommendation?.recommendation ?? ""),
                                .init(date: Date(), description: requiredReturnRecommendation),
                            ],
                            quotes: mapper.mapQuotes(quotes: quotes)
                        )
                    }
            }
    }
}

extension UserInstrumentController {
    func sell(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let dto = try req.content.decode(SellRq.self)
        return getPrice(for: dto.ticker, on: req).flatMap { quotes in
            if let lastPrice = quotes.last {
                return User
                    .getTransactions(for: dto.userId, on: req.db, state: .opened)
                    .flatMap { transactions -> EventLoopFuture<HTTPStatus> in
                        let trans = transactions
                            .filter { $0.$instrument.id == dto.ticker }
                            .sorted { lhs, rhs in
                                lhs.openDate < rhs.openDate
                            }
                        if trans.count < dto.count {
                            return req.eventLoop.future(HTTPStatus.badRequest)
                        } else {
                            return trans
                                .prefix(dto.count)
                                .reduce(into: [Transaction]()) { partialResult, item in
                                    item.closeDate =  Date()
                                    item.closePrice = lastPrice.close
                                    item.sellComment = dto.comment
                                    partialResult.append(item)
                                }
                                .map { transaction in
                                    transaction.save(on: req.db)
                                }
                                .flatten(on: req.eventLoop)
                                .transform(to: HTTPStatus.ok)
                        }
                }
            } else {
                return req.eventLoop.future(HTTPStatus.badRequest)
            }
        }
    }
    
    private func getPrice(for ticker: String, on req: Request) -> EventLoopFuture<[Quote]> {
        let uri = MoexService.build(ticker, queryParams: [
            "from": "\(Date().onlyDate) 00:00:00",
            "till": "\(Date().onlyDate) 23:59:59",
            "interval": "24"
        ])
        
        if Date().isWeekend {
            return Quotes
                .getLastQuote(for: ticker, on: req.db)
                .map {
                    let quote = Quote()
                    quote.open = $0.openPrice
                    quote.close = $0.closePrice
                    quote.ticker = $0.ticker
                    return [quote]
                }
        } else {
            return req.client
                .get(uri)
                .tryFlatMap { response in
                    let data = try response.content.decode(Result.self)
                    return req.eventLoop.future(self.map(data, ticker: ticker).suffix(50))
                }
        }
    }
    
    private func map(_ result: Result, ticker: String) -> [Quote] {
        result.candles.data.map { array in
            let quote = Quote()
            for i in 0..<result.candles.columns.count {
                switch i {
                case 0:
                    switch array[0] {
                    case .double(let str):
                        quote.open = str
                    default: break
                    }
                case 1:
                    switch array[1] {
                    case .double(let str):
                        quote.close = str
                    default: break
                    }
                case 2:
                    switch array[2] {
                    case .double(let str):
                        quote.high = str
                    default: break
                    }
                case 3:
                    switch array[3] {
                    case .double(let str):
                        quote.low = str
                    default: break
                    }
                case 4:
                    switch array[4] {
                    case .double(let str):
                        quote.value = str
                    default: break
                    }
                case 5:
                    switch array[5] {
                    case .double(let str):
                        quote.volume = str
                    default: break
                    }
                case 6:
                    switch array[6] {
                    case .string(let str):
                        quote.begin = str
                    default: break
                    }
                case 7:
                    switch array[7] {
                    case .string(let str):
                        quote.end = str
                    default: break
                    }
                default: break
                }
            }
            quote.ticker = ticker
            return quote
        }
    }
}

struct SellRq: Content {
    let userId: String
    let ticker: String
    let count: Int
    let comment: String?
}
