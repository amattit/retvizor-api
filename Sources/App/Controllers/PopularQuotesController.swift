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
        
    }
}

extension PopularQuotesController {
    func fetch(req: Request) throws -> EventLoopFuture<[PopularQuotesRs]> {
        Instrument
            .query(on: req.db)
            .all()
            .flatMap {
                $0.map { instrument in
                    instrument.$userInstruments
                        .query(on: req.db)
                        .count()
                        .map { count in
                            return PopularQuotesRs(
                                instrument: instrument,
                                score: count
                            )
                        }
                }
                .flatten(on: req.eventLoop)
            }
    }
}

struct PopularQuotesRs: Content {
    let instrument: Instrument
    let score: Int
}
