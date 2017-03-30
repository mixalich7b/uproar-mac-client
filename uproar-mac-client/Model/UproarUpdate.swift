//
//  UproarUpdate.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 30.03.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Cocoa
import ObjectMapper

enum UproarUpdate: ImmutableMappable {
    case addContent(UproarContent)
    
    init(map: Map) throws {
        let updateType: String = try map.value("update")
        switch updateType {
        case "add_content":
            self = .addContent(try map.value("data"))
            break
        default:
            throw MapError(key: "update", currentValue: updateType, reason: "Unknown update type")
        }
    }
    
    mutating func mapping(map: Map) {
    }
}
