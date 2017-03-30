//
//  UproarContent.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 30.03.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Cocoa
import ObjectMapper

enum UproarContent: ImmutableMappable {
    case youtube(String)
    case track(String)
    
    init(map: Map) throws {
        if let link: String = try? map.value("youtube_link.url") {
            self = .youtube(link)
        } else if let link: String = try? map.value("track.url") {
            self = .track(link)
        } else {
            throw MapError(key: "data", currentValue: (map.value() as [String: Any]?), reason: "Unknown content type")
        }
    }
    
    mutating func mapping(map: Map) {
    }
}
