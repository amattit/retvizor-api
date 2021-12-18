//
//  File.swift
//  
//
//  Created by Михаил Серегин on 18.12.2021.
//

import Foundation

extension UserInstrumentController {
    class Mapper {
        func mapQuotes(quotes: [Quotes]) -> [Double] {
            quotes.reduce(into: [Double]()) { partialResult, item in
                partialResult.append(item.closePrice)
            }
        }
        
        func mapStockRs(from instruments: [Instrument], and transactions: [Transaction]) -> [StockItemRs] {
            transactions.reduce(into: [String:[Transaction]]()) { partialResult, item in
                partialResult[item.$instrument.id, default: []].append(item)
            }
            .reduce(into: [StockItemRs]()) { partialResult, kv in
                if let instrument = instruments.first(where: { $0.ticker == kv.key }) {
                    let avgPrice = kv.value.reduce(into: 0.0) { partialResult, item in
                        partialResult += item.openPrice
                    } / Double(kv.value.count)
                    let openPriceSum = kv.value.reduce(into: 0.0) { partialResult, item in
                        partialResult += item.openPrice
                    }
                    partialResult.append(
                        StockItemRs(
                            imagePath: instrument.imagePath,
                            displayName: instrument.organizationName ?? "",
                            count: kv.value.count,
                            averagePrice: avgPrice,
                            openPriceSum: openPriceSum,
                            ticker: instrument.ticker
                        )
                    )
                }
            }
        }
    }
}
