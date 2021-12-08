import Fluent
import FluentMySQLDriver
import Leaf
import Vapor

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

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

    app.views.use(.leaf)

    // register routes
    try routes(app)
}
