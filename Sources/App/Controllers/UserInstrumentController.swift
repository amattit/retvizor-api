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
/// #Список инструментов
/// [GET] /api/v1/instruments
struct UserInstrumentController: RouteCollection {
    static var calculatedUserInstrumentsTip: [String: Date] = [:]
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
    }
}

extension UserInstrumentController {
    /// Список своих инструментов
    func index(req: Request) throws -> EventLoopFuture<[UserInstrument]> {
        
        guard let userId = req.parameters.get("id") else {
            throw Abort(.notFound)
        }
        return UserInstrument
            .query(on: req.db)
            .filter(\.$userId, .equal, userId)
            .all()
    }
    
    func indexV2(req: Request) throws -> EventLoopFuture<[GroupedUserInstrumentsRs]> {
        guard let userId = req.parameters.get("id") else {
            throw Abort(.notFound)
        }
        
        return try InstrumentController().fetchStocks(req).flatMap { stocks in
            return UserInstrument
                .query(on: req.db)
                .filter(\.$userId, .equal, userId)
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
                let stock = InstrumentController.stocks.first(where: { $0.ticker == instrument.$ticker.id})
                return MyStockRs(id: instrument.id ?? "", ticker: instrument.$ticker.id, displayName: stock?.displayName ?? "Неизвестная компания", image: stock?.image ?? "", date: instrument.date ?? Date()) }
        return req.client.get("https://retvizor.herokuapp.com/user_instruments/\(instrument.id ?? "")").tryFlatMap { data in
            req.logger.info("call python server on https://retvizor.herokuapp.com/user_instruments/\(instrument.id ?? "")")
            req.logger.info("request returned status: \(data.status.code.description)")
            if data.status.code == 200 {
                Self.calculatedUserInstrumentsTip[instrument.id ?? ""] = Date().startOfDay
            }
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
    
    func getDetails(req: Request, instrumentId: String, recommendation: InstrumentRecomendationRs?) throws -> EventLoopFuture<InstrumentWithTipResponse> {
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
                        InstrumentWithTipResponse(
                            id: instrument.id ?? "",
                            ticker: instrument.$ticker.id,
                            date: instrument.date ?? Date(),
                            tips: [
                                .init(date: Date(), description: recommendation?.recommendation ?? ""),
                                .init(date: Date(), description: recommendation?.requiredReturn?.description ?? "0"),
                            ],
                            quotes: mapQuotes(quotes: quotes)
                        )
                    }
            }
    }
    
    func mapQuotes(quotes: [Quotes]) -> [Double] {
        quotes.reduce(into: [Double]()) { partialResult, item in
            partialResult.append(item.closePrice)
        }
    }
}

struct CreateInstrumentRequest: Content {
    let userId: UUID
    let ticker: String
    let date: Date
}

struct InstrumentWithTipResponse: Content {
    let id: String
    let ticker: String
    let date: Date
    let tips: [Tip]; struct Tip: Content {
        let date: Date
        let description: String
    }
    
    let quotes: [Double]
}

struct GroupedUserInstrumentsRs: Content {
    let id: String
    let ticker: String
    let instruments: [MyStockRs]
}

extension Date {
    var startOfDay: Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: self)
    }
}

struct MyStockRs: Content {
    let id: String
    let ticker, displayName, image: String
    let date: Date
}

struct InstrumentRecomendationRs: Content {
    let recommendation: String?
    let requiredReturn: Double?
}
