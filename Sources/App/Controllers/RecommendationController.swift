//
//  File.swift
//  
//
//  Created by Михаил Серегин on 15.12.2021.
//

import Vapor

struct RecomendationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let recomendation = routes.grouped("api", "v1", "recomendations", "stocks")
        
        recomendation.get(use: index)
    }
    
    func index(req: Request) throws -> EventLoopFuture<[RecomendationResponse]> {
        return try InstrumentController().fetchStocks(req).flatMap { stocks in
            RecomendationQuote.query(on: req.db).filter(\.$buy, .equal, 1).all().map { recomenations in
                recomenations
                    .reduce(into: [String: [RecomendationQuote]]()) { partialResult, recomendation in
                        partialResult[recomendation.ticker, default: []].append(recomendation)
                    }
                    .reduce(into: [RecomendationResponse]()) { partialResult, keyValue in
                        if let stock = stocks.first(where: {$0.ticker == keyValue.key}) {
                            partialResult.append(RecomendationResponse(id: UUID().uuidString, stock: stock, recomendation: keyValue.value.sorted(by: { l, r in
                                l.date ?? Date() > r.date ?? Date()
                            })))
                        } else {
                            req.logger.info("\(keyValue.key) не найден в бумагах")
                        }
                    }
                
            }
        }
    }
}

struct RecomendationResponse: Content {
    let id: String
    let stock: StockRs
    let recomendation: [RecomendationQuote]
}
