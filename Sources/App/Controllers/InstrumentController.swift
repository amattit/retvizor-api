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
    func boot(routes: RoutesBuilder) throws {
        let instrument = routes.grouped("admin", "instruments")
        
        instrument.get(use: fetchInstruments)
        instrument.patch(use: updateInstrument)
        instrument.post(use: createInstrument)
        instrument.post("batch", use: batchCreate)
        instrument.delete(":id", use: delete)
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
        let dto = try req.content.decode([Instrument].self)
        return dto.map {
            Instrument(dto: $0)
                .save(on: req.db)
        }
        .flatten(on: req.eventLoop)
        .transform(to: HTTPStatus.ok)
    }
}

//MARK: delete
extension InstrumentController {
    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let id = req.parameters.get("id")
        else { throw Abort(.badRequest) }
        return Instrument.find(id, on: req.db)
            .unwrap(or: Abort(.notFound))
            .flatMap {
                $0
                    .delete(on: req.db)
                    .transform(to: HTTPStatus.ok)
            }
    }
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
