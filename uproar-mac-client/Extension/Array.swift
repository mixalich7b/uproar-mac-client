//
//  Array.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 09.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Foundation

extension Array {
    
    /// Returns the first element that satisfies the given
    /// predicate and remove it from the array.
    
    mutating func pullFirst(where predicate: (Element) throws -> Bool) rethrows -> Element? {
        if let idx = try self.index(where: predicate) {
            let value = self[idx]
            self.remove(at: idx)
            return value
        }
        return nil
    }
}
