import Fluent
import FluentMySQLDriver
import Leaf
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // mysql://o8ggpxenrsfpn918:ivjw9rs2xov3pcqu@d3y0lbg7abxmbuoi.chr7pe7iynqr.eu-west-1.rds.amazonaws.com:3306/abuk48ejk4359tvk
    //mysql://retvizor:jGA76A81@retvizor-db.c97va71oz3gr.us-east-2.rds.amazonaws.com/sys
    if let databaseURL = Environment.get("JAWSDB_URL") {
        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateVerification = .none

        let urlComponents = URLComponents(string: databaseURL)
        let host = urlComponents?.host ?? ""
        let port = urlComponents?.port ?? 3306
        let password = urlComponents?.password ?? ""
        let user = urlComponents?.user ?? ""
        let database = String(urlComponents?.path.dropFirst() ?? "")
        let config = MySQLConfiguration(hostname: host, port: port, username: user, password: password, database: database, tlsConfiguration: tls)
        
        app.databases.use(.mysql(configuration: config), as: .mysql)
    } else {
        app.databases.use(.mysql(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? MySQLConfiguration.ianaPortNumber,
            username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
            password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
            database: Environment.get("DATABASE_NAME") ?? "vapor_database"
        ), as: .mysql)
    }
//    app.migrations.add(CreateTodo())
    app.migrations.add(CreateTradeResult())
    app.migrations.add(CreateUserInstruments())
    app.migrations.add(CreateUserInstrumentTip())
    app.migrations.add(CreateRecomendationQuote())
    app.migrations.add(CreateQuotes())
    app.migrations.add(CreateQuotesActuality())

    app.views.use(.leaf)

    

    // register routes
    try routes(app)
}
