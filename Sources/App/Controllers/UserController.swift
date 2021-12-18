//
//  File.swift
//  
//
//  Created by Михаил Серегин on 17.12.2021.
//

import Vapor
import FluentKit

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.post("user", use: signIn)
        routes.get("user", ":userId", use: getUser)
    }
}

extension UserController {
    func signIn(req: Request) throws -> EventLoopFuture<User> {
        let userRq = try req.content.decode(UserSignInRq.self)
        return User
            .query(on: req.db)
            .filter(\.$id == userRq.userId)
            .first()
            .flatMap { user -> EventLoopFuture<User> in
                if user == nil {
                    let user = User(userid: userRq.userId)
                    return user
                        .save(on: req.db)
                        .map {
                            return user
                        }
                } else {
                    return req.eventLoop.future(user!)
                }
            }
    }
    
    func getUser(req: Request) throws -> EventLoopFuture<UserResponse> {
        guard let userId = req.parameters.get("userId") else { throw Abort(.badRequest) }
        return User.find(userId, on: req.db)
            .unwrap(or: Abort(.notFound, reason: "Пользователь не найден"))
            .flatMap { user in
                let userInstruments = user.$userInstruments
                    .get(on: req.db)
                    .map { userInstruments in
                        userInstruments
                            .reduce(into: [String:[UserInstrument]]()) { partialResult, userInstrument in
                                partialResult[userInstrument.$ticker.id, default: []].append(userInstrument)
                            }
                    }
                return userInstruments.tryFlatMap { ui -> EventLoopFuture<[GroupedUserInstrumentsRs]> in
                    let keys = ui.keys
                    return Instrument
                        .query(on: req.db)
                        .filter(\.$ticker ~~ keys.map { $0 })
                        .all()
                        .map { stocks in
                            return ui
                                .reduce(into: [GroupedUserInstrumentsRs]()) { partialResult, keyValue in
                                    let stock = stocks.first(where: { $0.ticker == keyValue.key})
                                    let items = keyValue.value.map {
                                        MyStockRs(id: $0.id ?? "", ticker:$0.$ticker.id, displayName: stock?.organizationName ?? "Неизвестное название", image: stock?.imagePath ?? "", date: $0.date ?? Date())
                                    }
                                    partialResult.append(.init(id: UUID().uuidString, ticker: keyValue.key, instruments: items))
                                }
                        }
                }
                .map {
                    UserResponse(id: user.id!, groupedInstruments: $0)
                }
            }
    }
}

final class User: Model, Content {
    static var schema = "user"
    
    @ID(custom: "id")
    var id: String?
    
    @Children(for: \.$user)
    var userInstruments: [UserInstrument]
    
    @Children(for: \.$user)
    var transactions: [Transaction]
    
    init() {
        id = UUID().uuidString
    }
    
    init(userid: String) {
        self.id = userid
    }
    
}

struct UserSignInRq: Content {
    let userId: String
}

struct UserResponse: Content {
    var id: String
    var groupedInstruments: [GroupedUserInstrumentsRs]
}

extension User {
    static func getTransactions(for userId: String?, on db: Database, state: TransactionState = .opened) -> EventLoopFuture<[Transaction]> {
        User.find(userId, on: db)
            .unwrap(or: Abort(.notFound, reason: "Пользователь не найден"))
            .flatMap { user in
                user.$transactions.get(on: db).map {
                    switch state {
                    case .opened:
                        return $0.filter { $0.closeDate == nil }
                    case .closed:
                        return $0.filter { $0.closeDate != nil }
                    case .all:
                        return $0
                    }
                }
            }
    }
    
    enum TransactionState {
        case opened, closed, all
    }
}
