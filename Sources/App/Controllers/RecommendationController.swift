//
//  File.swift
//  
//
//  Created by Михаил Серегин on 15.12.2021.
//

import Vapor
import Fluent

struct RecomendationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let recomendation = routes.grouped("api", "v1", "recomendations", "stocks")
        recomendation.get(use: index)
        
        let rec = routes.grouped("api", "v1", "recommendations")
        rec.get(use: self.rec)
        
    }
    
    func index(req: Request) throws -> EventLoopFuture<[RecomendationResponse]> {
        return try InstrumentController().fetchStocks(req).flatMap { stocks in
            RecomendationQuote.query(on: req.db).filter(\.$buy, .equal, 1).all().map { recomenations in
                recomenations
                    .reduce(into: [String: [RecomendationQuote]]()) { partialResult, recomendation in
                        partialResult[recomendation.ticker, default: []].append(recomendation)
                    }
                    .reduce(into: [RecomendationResponse]()) { partialResult, keyValue in
                        if let stock = stocks.first(where: {$0.ticker == keyValue.key}) {
                            partialResult.append(RecomendationResponse(id: UUID().uuidString, stock: stock, recomendation: keyValue.value.sorted(by: { l, r in
                                l.date ?? Date() > r.date ?? Date()
                            })))
                        } else {
                            req.logger.info("\(keyValue.key) не найден в бумагах")
                        }
                    }
                
            }
        }
    }
    
    func rec(req: Request) throws -> EventLoopFuture<[RecomendationRs]> {
        let type = try req.query.decode(RecommendationRq.self)
        switch type.type {
        case .recommendation:
            return try recommendations(req: req)
        case .popular:
            return try popular(req: req)
        }
    }
    
    func recommendations(req: Request) throws -> EventLoopFuture<[RecomendationRs]> {
        RecomendationQuote
            .query(on: req.db)
            .filter(\.$date > Date().startOfDay.advanced(by: -3600 * 24 * 2))
            .filter(\.$buy == 1)
            .all()
            .tryFlatMap { periods in
                let tickers = Array(Set(periods.map { $0.ticker }))
                return Quotes.getLastQuote(for: tickers, on: req).flatMap { quotes in
                    return Instrument.getSet(for: tickers, in: req.db).map { instruments in
                        map(periods: periods, instruments: instruments, quotes: quotes)
                    }
                }
            }
    }
    
    func popular(req: Request) throws -> EventLoopFuture<[RecomendationRs]> {
        Instrument
            .query(on: req.db)
            .join(UserInstrument.self, on: \Instrument.$ticker == \UserInstrument.$ticker.$id)
            .with(\.$userInstruments)
            .all()
            .flatMap { instruments in
                let count =  instruments.reduce(into: [String:Int]()) { partialResult, instrument in
                    partialResult[instrument.ticker, default: 0] += 1
                }
                let dict = instruments.reduce(into: [String:Instrument]()) { partialResult, instrument in
                    partialResult[instrument.ticker] = instrument
                }
                let tickers = dict.map { $0.key }
                return Quotes.getLastQuote(for: tickers, on: req)
                    .map { quotes in
                        return dict.map { item -> RecomendationRs in
                            let quote = quotes.first { $0.ticker == item.value.ticker }
                            return RecomendationRs(
                                id: item.value.id ?? "",
                                ticker: item.value.ticker,
                                displayName: item.value.organizationName ?? "",
                                image: item.value.imagePath,
                                periods: nil,
                                score: count[item.value.ticker] ?? 0,
                                price: Decimal(quote?.closePrice ?? 0)
                            )
                        }
                        .sorted {
                            $0.score ?? 0 > $1.score ?? 0
                        }
                    }
            }
    }
    
    func map(periods: [RecomendationQuote], instruments: [Instrument], quotes: [Quotes]) -> [RecomendationRs] {
        periods
            .reduce(into: [String:[RecomendationQuote]]()) { partialResult, item in
                partialResult[item.ticker, default: []].append(item)
            }
            .reduce(into: [RecomendationRs]()) { partialResult, keyValue in
                if let instrument = instruments.first(where: { instrument in
                    instrument.ticker == keyValue.key
                }) {
                    let periods = keyValue.value
                        .sorted { $0.date ?? Date() < $1.date ?? Date() }
                        .reduce(into: [Int: RecomendationQuote]()) { partialResult, item in
                            partialResult[item.tipPeriod] = item
                        }
                        .compactMap { $0.value }
                        .sorted { $0.tipPeriod < $1.tipPeriod }
                    let quote = quotes.first { $0.ticker == keyValue.key }
                    partialResult.append(RecomendationRs(
                        id: UUID().uuidString,
                        ticker: keyValue.key,
                        displayName: instrument.organizationName,
                        image: instrument.imagePath,
                        periods: periods.map { RecomendationRs.Period(id: $0.id ?? "", date: $0.date ?? Date(), period: $0.tipPeriod, buy: $0.buy)},
                        score: nil,
                        price: Decimal(quote?.closePrice ?? 0)
                    ))
                }
            }
            .sorted { $0.ticker < $1.ticker }
    }
}

struct RecomendationResponse: Content {
    let id: String
    let stock: StockRs
    let recomendation: [RecomendationQuote]
}

struct RecommendationRq: Content {
    let type: RecommendationType; enum RecommendationType: String, Content {
        case recommendation, popular
    }
}
struct RecomendationRs: Content {
    let id,ticker: String
    let displayName, image: String?
    let periods: [Period]?; struct Period: Content {
        let id: String
        let date: Date
        let period: Int
        let buy: Int
    }
    let score: Int?
    let price: Decimal
}
