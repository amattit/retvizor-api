//
//  File.swift
//  
//
//  Created by Михаил Серегин on 13.12.2021.
//

import Vapor
import Foundation

struct CandlesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("api", "v1", "quotes","daily", ":ticker", use: index)
        routes.get("api", "v1", "quotes", ":ticker", use: all)
    }
}

struct MoexService {
    static let scheme = "https"
    static let host = "iss.moex.com"
    
    static let index = "index"
    static let quotes = "shares"
    
//     http://iss.moex.com/iss/engines/stock/markets/index/securities/imoex/candles.csv?from={start_dt}&till={en_dt}&interval=24
    static func build(_ payload: String, queryParams: [String: String]) -> URI {
        let type = isIndex(payload) ? index : quotes
        var componrnts = URLComponents()
        componrnts.scheme = scheme
        componrnts.host = host
        componrnts.path = "/iss/engines/stock/markets/\(type)/securities/\(payload)/candles.json"
        componrnts.queryItems = queryParams.compactMap {
            URLQueryItem(name: $0.key, value: $0.value)
        }
        let string = componrnts.string ?? ""
        return URI(string: string)
    }
    
    
    private static func isIndex(_ payload: String) -> Bool {
        payload.uppercased() == "IMOEX" ? true : false
    }
    
    static func map(_ result: Result, ticker: String) -> [Quote] {
        result.candles.data.map { array in
            let quote = Quote()
            for i in 0..<result.candles.columns.count {
                switch i {
                case 0:
                    switch array[0] {
                    case .double(let str):
                        quote.open = str
                    default: break
                    }
                case 1:
                    switch array[1] {
                    case .double(let str):
                        quote.close = str
                    default: break
                    }
                case 2:
                    switch array[2] {
                    case .double(let str):
                        quote.high = str
                    default: break
                    }
                case 3:
                    switch array[3] {
                    case .double(let str):
                        quote.low = str
                    default: break
                    }
                case 4:
                    switch array[4] {
                    case .double(let str):
                        quote.value = str
                    default: break
                    }
                case 5:
                    switch array[5] {
                    case .double(let str):
                        quote.volume = str
                    default: break
                    }
                case 6:
                    switch array[6] {
                    case .string(let str):
                        quote.begin = str
                    default: break
                    }
                case 7:
                    switch array[7] {
                    case .string(let str):
                        quote.end = str
                    default: break
                    }
                default: break
                }
            }
            quote.ticker = ticker
            return quote
        }
    }
}

extension CandlesController {
    func all(req: Request) throws -> EventLoopFuture<[Quote]> {
        guard let ticker = req.parameters.get("ticker") else { throw Abort(.badRequest, reason: "Должен быть path параметр ticker") }

        let uris = getURIForYears(2015...Date().year, ticker: ticker)
        
        return uris.map { uri in
            return req
                .client
                .get(uri)
                .map { response -> [Quote] in
                    if let data = try? response.content.decode(Result.self) {
                        return MoexService.map(data, ticker: ticker)
                    } else {
                        return []
                    }
                }
        }
            .flatten(on: req.eventLoop)
            .map { $0.flatMap { $0 } }
    }
    
    func getURIForYears(_ years: ClosedRange<Int>, ticker: String) -> [URI] {
        let intervals = years.map { year in
            Date.dateInterval(for: year)
        }
        
        return intervals.map { interval in
            let params: [String: String] = [
                "from": "\(interval.start.onlyDate)) 00:00:00",
                "till": "\(interval.end.onlyDate) 23:59:59",
                "interval": "24"
            ]
            return MoexService.build(ticker, queryParams: params)
        }
    }
    
    func index(req: Request) throws -> EventLoopFuture<[Quote]> {
        guard let ticker = req.parameters.get("ticker") else { throw Abort(.badRequest)}
        let uri = MoexService.build(ticker, queryParams: [
            "from": "\(Date().onlyDate) 00:00:00",
            "till": "\(Date().onlyDate) 23:59:59",
            "interval": "1"
        ])
        
        
        if Date().isWeekend {
            return Quotes
                .getLastQuote(for: ticker, on: req.db)
                .map {
                    let quote = Quote()
                    quote.open = $0.openPrice
                    quote.close = $0.closePrice
                    quote.ticker = $0.ticker
                    return [quote]
                }
        } else {
            return req.client
                .get(uri)
                .tryFlatMap { response in
                    let data = try response.content.decode(Result.self)
                    return req.eventLoop.future(MoexService.map(data, ticker: ticker).suffix(50))
                }
        }
    }
}

extension Date {
    var isWeekend: Bool {
        Calendar.current.isDateInWeekend(self)
    }
}

final class Quote: Hashable, Equatable, Content {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(begin)
        hasher.combine(end)
    }
    
    static func == (lhs: Quote, rhs: Quote) -> Bool {
        lhs.open == rhs.open
        && lhs.close == rhs.close
        && lhs.high == rhs.high
        && lhs.low == rhs.low
        && lhs.value == rhs.value
        && lhs.volume == rhs.volume
        && lhs.begin == rhs.begin
        && lhs.end == rhs.end
    }
    
    var open, close, high, low, value, volume: Double?
    var begin, end: String?
    var ticker: String?
    
    init() {}
}

extension Quote: CustomStringConvertible {
    var description: String {
        """
        open: \(open ?? 0),
        close: \(close ?? 0),
        high: \(high ?? 0),
        low: \(low ?? 0),
        value: \(value ?? 0),
        volume: \(volume ?? 0),
        begin: \(begin ?? ""),
        end: \(end ?? "")
        """
    }
}

extension Date: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    
    public init(stringLiteral value: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-dd"
        self = formatter.date(from: value) ?? Date()
    }
    
    static func dateInterval(for year: Int) -> DateInterval {
        DateInterval(start: Date(stringLiteral: "\(year)-01-01"), end: Date())
    }
}

public extension Date {
    var endOfDay: Date {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: 1, to: self)?.startOfDay ?? Date().startOfDay
        let result = calendar.date(byAdding: .minute, value: -1, to: date) ?? Date().startOfDay
        
        return result
    }
    
    var onlyDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd"
        return dateFormatter.string(from: self)
    }
    
    var year: Int {
        Calendar.current.component(.year, from: self)
    }
}
    
struct Subscribe: Codable {
    let ticker: String
}

// MARK: - Result
struct Result: Codable, Content {
    let candles: Candles
}

// MARK: - Candles
struct Candles: Codable, Content {
    let metadata: Metadata
    let columns: [String]
    let data: [[Datum]]
}

enum Datum: Codable, Content {
    case double(Double)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Double.self) {
            self = .double(x)
            return
        }
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        throw DecodingError.typeMismatch(Datum.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for Datum"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .double(let x):
            try container.encode(x)
        case .string(let x):
            try container.encode(x)
        }
    }
}

// MARK: - Metadata
struct Metadata: Codable, Content {
    let metadataOpen, close, high, low: Close
    let value, volume: Close
    let begin, end: Begin

    enum CodingKeys: String, CodingKey {
        case metadataOpen = "open"
        case close, high, low, value, volume, begin, end
    }
}

// MARK: - Begin
struct Begin: Codable, Content {
    let type: String
    let bytes, maxSize: Int

    enum CodingKeys: String, CodingKey {
        case type, bytes
        case maxSize = "max_size"
    }
}

// MARK: - Close
struct Close: Codable, Content {
    let type: String
}
