//
//  UproarMessage.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 30.03.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Cocoa
import ObjectMapper

enum UproarMessage: ImmutableMappable, CustomDebugStringConvertible {
    case trackStatus(UproarTrackStatus, String)
    case boring(String)
    
    init(map: Map) throws {
        throw MapError(key: "update", currentValue: (map.value() as [String: Any]?), reason: "Use cases")
    }
    
    mutating func mapping(map: Map) {
        switch self {
        case .trackStatus(let trackStatus, let token):
            "update_track_status" >>> map["update"]
            token >>> map["token"]
            trackStatus >>> map["data"]
            break
        case .boring(let token):
            "boring" >>> map["update"]
            token >>> map["token"]
            break
        }
    }
    
    var debugDescription: String {
        get {
            switch self {
            case .trackStatus(let trackStatus, _):
                return "Change \(trackStatus.debugDescription)"
            default:
                return "Boring"
            }
        }
    }
}
