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
struct UserInstrumentController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let instruments = routes.grouped("api", "v1", "user")
        
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
    
    /// Добавление нового инструмента
    func create(req: Request) throws -> EventLoopFuture<UserInstrument> {
        let dto = try req.content.decode(CreateInstrumentRequest.self)
        let instrument = UserInstrument(with: dto)
        
        return instrument.save(on: req.db)
            .map { instrument }
    }
    
    /// Удаление своего инструмента
    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let id = req.parameters.get("id")
        
        return UserInstrument.find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { $0.delete(on: req.db)}
            .transform(to: .ok)
    }
    
    func details(req: Request) throws -> EventLoopFuture<InstrumentWithTipResponse> {
        guard
            let instrumentId = req.parameters.get("id")
        else { throw Abort(.notFound) }
        
        return UserInstrument
            .find(instrumentId, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap { instrument in
                UserInstrumentTip
                    .query(on: req.db)
                    .filter(\.$instrumentId, .equal, instrumentId)
                    .all()
                    .map { tips in
                        InstrumentWithTipResponse(
                            id: instrument.id ?? "",
                            ticker: instrument.ticker,
                            date: instrument.date ?? Date(),
                            tips: tips.map {
                                InstrumentWithTipResponse.Tip(
                                    date: $0.date ?? Date(),
                                    description: $0.tip
                                )
                            }
                        )
                    }
        }
    }
}

struct CreateInstrumentRequest: Content {
    let userId: String
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
