//
//  File.swift
//  
//
//  Created by Михаил Серегин on 10.12.2021.
//

import Vapor
import Fluent

struct PopularQuotesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("api", "v1", "popular", use: fetch)
    }
}

extension PopularQuotesController {
    func fetch(req: Request) throws -> EventLoopFuture<[PopularQuotesRs]> {
        Instrument
            .query(on: req.db)
            .join(UserInstrument.self, on: \Instrument.$ticker == \UserInstrument.$ticker.$id)
            .with(\.$userInstruments)
            .all()
            .map { instruments in
                let count =  instruments.reduce(into: [String:Int]()) { partialResult, instrument in
                    partialResult[instrument.ticker, default: 0] += 1
                }
                let dict = instruments.reduce(into: [String:Instrument]()) { partialResult, instrument in
                    partialResult[instrument.ticker] = instrument
                }
                
                return dict.map {
                    let stock = MyStockRs(id: $0.value.id ?? "", ticker: $0.value.ticker, displayName: $0.value.organizationName ?? "", image: $0.value.imagePath ?? "",date: Date())
                    return PopularQuotesRs(instrument: stock, score: count[stock.ticker] ?? 0)
                }
                .sorted {
                    $0.score > $1.score
                }
            }
//            .flatMap {
//                $0.map { instrument in
//                    instrument.$userInstruments
//                        .query(on: req.db)
//                        .count()
//                        .map { count in
//                            return PopularQuotesRs(
//                                instrument: instrument,
//                                score: count
//                            )
//                        }
//                }
//                .flatten(on: req.eventLoop)
//            }
    }
}

struct PopularQuotesRs: Content {
    let instrument: MyStockRs
    let score: Int
}
