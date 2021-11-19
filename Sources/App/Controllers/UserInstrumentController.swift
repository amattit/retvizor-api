//
//  File.swift
//  
//
//  Created by 16997598 on 19.11.2021.
//

import Vapor


/// #API
/// #Свои инструменты
/// [GET] /api/v1/instruments/:id - список своих инструментов
/// [POST] /api/v1/instruments -  добавить свой инструмент
/// [DELETE] /api/v1/instruments/:id - удалить свой инструмент
///
/// #Рекоментации
/// [GET] /api/v1/recomendations/stocks - Рекомендуемые к покупке
///
struct UserInstrumentController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let instruments = routes.grouped("api", "v1", "instruments")
        
        // Получить свои инструменты
        instruments.group(":id") { instrument in
            instrument.get(use: index)
            instrument.delete(use: delete)
        }
        
        instruments.post(use: create)
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
}

struct CreateInstrumentRequest: Content {
    let userId: String
    let ticker: String
    let date: Date
}
