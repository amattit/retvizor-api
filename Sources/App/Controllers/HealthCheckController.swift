//
//  File.swift
//  
//
//  Created by Михаил Серегин on 15.12.2021.
//

import Vapor

struct HealthCheckController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let root = routes.grouped("health-check")
        root.get(use: index)
        routes.get("routes", use: allRoutes)
    }
    
    func index(req: Request) throws -> HTTPStatus {
        return HTTPStatus.ok
    }
    
    func allRoutes(req: Request) throws -> [RouteRs] {
        return req.application.routes.all.map {
            RouteRs(route: $0.description)
        }
    }
}

struct RouteRs: Content {
    let route: String
}
