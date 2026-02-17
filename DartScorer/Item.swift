//
//  Item.swift
//  DartScorer
//
//  Created by Leon Stockmann on 17.02.26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
