import Fluent
import FluentMySQLDriver
import Leaf
import Vapor
import Queues
import QueuesRedisDriver

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
        
        app.databases.use(.mysql(configuration: config, connectionPoolTimeout: .minutes(1)), as: .mysql)
    } else {
        app.databases.use(.mysql(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? MySQLConfiguration.ianaPortNumber,
            username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
            password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
            database: Environment.get("DATABASE_NAME") ?? "vapor_database"
        ), as: .mysql)
    }
    
    if let redisUrl = Environment.get("REDIS_URL") {        
        try app.queues.use(.redis(RedisConfiguration(url: redisUrl, pool: RedisConfiguration.PoolOptions(
            maximumConnectionCount: RedisConnectionPoolSize.maximumActiveConnections(20),
            minimumConnectionCount: 0,
            connectionBackoffFactor: 0,
            initialConnectionBackoffDelay: .seconds(10),
            connectionRetryTimeout: .seconds(1)))))
        let job = QuoteUpdateJob()
        app.queues.add(job)
        try app.queues.startInProcessJobs(on: .default)
    }

    app.get("api", "v1", "quotes", "update") { req -> EventLoopFuture<HTTPStatus> in
        return Quotes
            .query(on: req.db)
            .filter(\.$date > Date().advanced(by: -3600 * 24 * 3))
            .sort(\.$date)
            .all()
            .flatMap {
                $0
                    .reduce(into: [String: Quotes]()) { partialResult, item in
                        partialResult[item.ticker] = item
                    }
                    .reduce(into: [Quotes]()) { partialResult, item in
                        partialResult.append(item.value)
                    }
                    .map {
                        return req.queue.dispatch(QuoteUpdateJob.self, $0)
                    }
                    .flatten(on: req.eventLoop)
                .transform(to: HTTPStatus.ok)
            }
    }
    app.views.use(.leaf)

    // register routes
    try routes(app)
}
