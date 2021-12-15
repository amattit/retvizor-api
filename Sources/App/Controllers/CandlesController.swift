//
//  File.swift
//  
//
//  Created by Михаил Серегин on 13.12.2021.
//

import Vapor

struct CandlesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("api", "v1", "quotes","daily", ":ticker", use: index)
    }
}

extension CandlesController {
    func index(req: Request) throws -> EventLoopFuture<[Quote]> {
        guard let ticker = req.parameters.get("ticker") else { throw Abort(.badRequest)}
        var componrnts = URLComponents()
        componrnts.queryItems = [
            URLQueryItem(name: "from", value: "\(Date().onlyDate) 00:00:00"),
            URLQueryItem(name: "till", value: "\(Date().onlyDate) 23:59:59"),
            URLQueryItem(name: "interval", value: 1.description)
        ]
        componrnts.scheme = "https"
        componrnts.host = "iss.moex.com"
        componrnts.path = "/iss/engines/stock/markets/shares/securities/\(ticker)/candles.json"
        let string = componrnts.string ?? ""
        let uri = URI(string: string)
        return req.client
            .get(uri)
            .tryFlatMap { response in
                let data = try response.content.decode(Result.self)
                return req.eventLoop.future(self.map(data, ticker: ticker).suffix(50))
            }
    }
    
    func map(_ result: Result, ticker: String) -> [Quote] {
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
