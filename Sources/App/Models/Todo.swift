import Fluent
import Vapor

final class Todo: Model, Content {
    static let schema = "todos"
    
    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    init() { }

    init(id: UUID? = nil, title: String) {
        self.id = id
        self.title = title
    }
}

final class TradeResult: Model, Content {
    static let schema = "trade_result"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "tradeDate")
    var date: Date?
    
    @Field(key: "isGood")
    var isGood: Bool
    
    @Field(key: "info")
    var info: String?
    
    @Field(key: "userId")
    var userId: String
    
    init() {}
    
    init(id: UUID? = nil, date: Date, isGood: Bool, info: String?, userId: String) {
        self.id = id
        self.date = date
        self.isGood = isGood
        self.info = info
        self.userId = userId
    }
}
