//
//  File.swift
//  
//
//  Created by MikhailSeregin on 22.12.2021.
//

import Foundation
import Queues
import Vapor

struct QuoteUpdateJob: Job {
    typealias Payload = Quotes
    
    func dequeue(_ context: QueueContext, _ payload: Quotes) -> EventLoopFuture<Void> {
        let ticker = payload.ticker
        let queryParams = [
            "from": Date().onlyDate,
            "interval":"24"
        ]
        let uri = MoexService.build(ticker, queryParams: queryParams)
        return context.application.client.get(uri).flatMap { response -> EventLoopFuture<Void> in
            if let data = try? response.content.decode(Result.self) {
                let quotes = map(data, ticker: ticker)
                if quotes.count > 1 {
                    context.logger.warning("В запросе на обновление котировки вернулось более одной котировке")
                }
                if let quote = quotes.last {
                    if quote.end?.prefix(10) ?? "" == payload.date?.onlyDate ?? "" {
                        return Quotes.find(payload.id, on: context.application.db).unwrap(or: Abort(.notFound)).flatMap { q in
                            q.closePrice = quote.close ?? 0
                            context.logger.info("котировка \n\(payload.description) \nОбновлена")
                            return q.update(on: context.application.db)
                            
                        }
//                        payload.closePrice = quote.close ?? 0
                    } else {
                        let newQuote = Quotes()
                        newQuote.id = UUID().uuidString
                        newQuote.date = getDateFrom(string: quote.begin!)
                        newQuote.openPrice = quote.open ?? 0
                        newQuote.closePrice = quote.close ?? 0
                        newQuote.ticker = ticker
                        newQuote.volume = quote.volume
                        newQuote.lowPrice = quote.low
                        newQuote.highPrice = quote.high
                        return newQuote.create(on: context.application.db).map {
                            context.logger.info("котировка \(newQuote.description) создана")
                            return $0
                        }
                    }
                } else {
                    context.logger.warning("\(uri.string)")
                    context.logger.warning("В запросе на обновление котировки не вернуись котировки")
                    return context.eventLoop.future()
                }
                
            } else {
                context.logger.warning("Не удалось распарсить ответ")
                return context.eventLoop.future()
            }
        }
    }
    
    func getDateFrom(string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return (formatter.date(from: string) ?? Date())//.advanced(by: -3600*3)
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: Quotes) -> EventLoopFuture<Void> {
        // если что то пошло не так
        return context.eventLoop.future()
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
