//
//  File.swift
//  
//
//  Created by Михаил Серегин on 18.12.2021.
//

import Foundation
import Vapor

struct CreateInstrumentRequest: Content {
    let userId: UUID
    let ticker: String
    let date: Date
    let count: Int?
    let price: Double?
    let comment: String?
}

struct InstrumentWithTipResponse: Content {
    let id: String
    let ticker: String
    let date: Date
    let tips: [Tip]; struct Tip: Content {
        let date: Date
        let description: String
    }
    
    let quotes: [Double]
}

@available(*, deprecated, message: "")
struct GroupedUserInstrumentsRs: Content {
    let id: String
    let ticker: String
    let instruments: [MyStockRs]
}

struct StockItemRs: Content {
    let imagePath: String?
    let displayName: String
    let count: Int
    let averagePrice: Double
    let openPriceSum: Double
    let ticker: String
}

extension Date {
    var startOfDay: Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: self)
    }
    
    var shortFormat: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.YYYY"
        return formatter.string(from: self)
    }
}

struct MyStockRs: Content {
    let id: String
    let ticker, displayName, image: String
    let date: Date
}

struct InstrumentRecomendationRs: Content {
    let recommendation: String?
    let requiredReturn: Double?
}
