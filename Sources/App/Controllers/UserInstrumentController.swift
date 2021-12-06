//
//  File.swift
//  
//
//  Created by 16997598 on 19.11.2021.
//

import Vapor


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

struct HealthCheckController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let root = routes.grouped("health-check")
        root.get(use: index)
    }
    
    func index(req: Request) throws -> HTTPStatus {
        return HTTPStatus.ok
    }
}

struct UserInstrumentController: RouteCollection {
    static var calculatedUserInstrumentsTip: [UUID: Date] = [:]
    func boot(routes: RoutesBuilder) throws {
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
    }
}

extension UserInstrumentController {
    /// Список своих инструментов
    func index(req: Request) throws -> EventLoopFuture<[UserInstrument]> {
        
        guard let userId = UUID(uuidString: req.parameters.get("id") ?? "") else {
            throw Abort(.notFound)
        }
        return UserInstrument
            .query(on: req.db)
            .filter(\.$userId, .equal, userId)
            .all()
    }
    
    func indexV2(req: Request) throws -> EventLoopFuture<[GroupedUserInstrumentsRs]> {
        
        guard let userId = UUID(uuidString: req.parameters.get("id") ?? "") else {
            throw Abort(.notFound)
        }
        return UserInstrument
            .query(on: req.db)
            .filter(\.$userId, .equal, userId)
            .all()
            .map {
                $0.reduce(into: [String:[UserInstrument]]()) { partialResult, instrument in
                    partialResult[instrument.ticker, default: []].append(instrument)
                }
                .reduce(into: [GroupedUserInstrumentsRs]()) { partialResult, keyValue in
                    partialResult.append(GroupedUserInstrumentsRs(id: UUID().uuidString, ticker: keyValue.key, instruments: keyValue.value))
                }
            }
    }
    
    /// Добавление нового инструмента
    func create(req: Request) throws -> EventLoopFuture<UserInstrument> {
        let dto = try req.content.decode(CreateInstrumentRequest.self)
        let instrument = UserInstrument(with: dto)
        
        let response = instrument.save(on: req.db)
            .map { instrument }
        return req.client.get("https://retvizor.herokuapp.com/user_instruments/\(instrument.id?.uuidString ?? "")").tryFlatMap { data in
            req.logger.info("call python server on https://retvizor.herokuapp.com/user_instruments/\(instrument.id?.uuidString ?? "")")
            req.logger.info("request returned status: \(data.status.code.description)")
            if data.status.code == 200 {
                Self.calculatedUserInstrumentsTip[try instrument.requireID()] = Date().startOfDay
            }
            return response
        }
    }
    
    /// Удаление своего инструмента
    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let id = UUID(uuidString: req.parameters.get("id") ?? "") else { throw Abort(.badRequest) }
        
        return UserInstrument.find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { $0.delete(on: req.db)}
            .transform(to: .ok)
    }
    
    func details(req: Request) throws -> EventLoopFuture<InstrumentWithTipResponse> {
        guard let instrumentId = UUID(uuidString: req.parameters.get("id") ?? "") else { throw Abort(.badRequest) }
        if Self.calculatedUserInstrumentsTip[instrumentId] == Date().startOfDay {
            return try getDetails(req: req, instrumentId: instrumentId)
        } else {
            return req.client.get("https://retvizor.herokuapp.com/user_instruments/\(instrumentId)").tryFlatMap { data in
                req.logger.info("call python server on https://retvizor.herokuapp.com/user_instruments/\(instrumentId)")
                req.logger.info("request returned status: \(data.status.code.description)")
                if data.status.code == 200 {
                    Self.calculatedUserInstrumentsTip[instrumentId] = Date().startOfDay
                }
                return try getDetails(req: req, instrumentId: instrumentId)
            }
        }
    }
    
    func getDetails(req: Request, instrumentId: UUID) throws -> EventLoopFuture<InstrumentWithTipResponse> {
        return UserInstrument
            .find(instrumentId, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { instrument in
                UserInstrumentTip
                    .query(on: req.db)
                    .filter(\.$instrumentId, .equal, instrumentId)
                    .all()
                    .flatMap { tips in
                        Quotes.query(on: req.db)
                            .group(.and) { group in
                                group
                                    .filter(\.$ticker, .equal, instrument.ticker)
                                    .filter(\.$date, .lessThanOrEqual, Date())
                                    .filter(\.$date, .greaterThan, instrument.date)
                            }
                            .all()
                            .map { quotes in
                                InstrumentWithTipResponse(
                                    id: instrument.id ?? UUID(),
                                    ticker: instrument.ticker,
                                    date: instrument.date ?? Date(),
                                    tips: tips.map {
                                        InstrumentWithTipResponse.Tip(
                                            date: $0.date ?? Date(),
                                            description: $0.tip
                                        )
                                    },
                                    quotes: mapQuotes(quotes: quotes)
                                )
                            }
                    }
            }
    }
    
    func mapQuotes(quotes: [Quotes]) -> [Double] {
        var items = [Double]()
        
        for quote in quotes {
            if quote == quotes.first {
                items.append(quote.openPrice)
            } else {
                items.append(quote.closePrice)
            }
        }
        
        return items
    }
}

struct CreateInstrumentRequest: Content {
    let userId: UUID
    let ticker: String
    let date: Date
}

struct InstrumentWithTipResponse: Content {
    let id: UUID
    let ticker: String
    let date: Date
    let tips: [Tip]; struct Tip: Content {
        let date: Date
        let description: String
    }
    
    let quotes: [Double]
}

struct RecomendationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let recomendation = routes.grouped("api", "v1", "recomendations", "stocks")
        
        recomendation.get(use: index)
    }
    
    func index(req: Request) throws -> EventLoopFuture<[RecomendationQuote]> {
        RecomendationQuote.query(on: req.db).filter(\.$buy, .equal, 1).all()
    }
}

struct GroupedUserInstrumentsRs: Content {
    let id: String
    let ticker: String
    let instruments: [UserInstrument]
}

extension Date {
    var startOfDay: Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: self)
    }
}
