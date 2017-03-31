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
    case youtube(String, Int, Int, Int)
    case audio(String, Int, Int, Int)
    
    init(map: Map) throws {
        if let link: String = try? map.value("youtube_link.url") {
            let orig: Int = try! map.value("youtube_link.orig")
            let messageId: Int = try! map.value("youtube_link.message_id")
            let chatId: Int = try! map.value("youtube_link.chat_id")
            self = .youtube(link, orig, messageId, chatId)
        } else if let link: String = try? map.value("audio.track_url") {
            let orig: Int = try! map.value("audio.orig")
            let messageId: Int = try! map.value("audio.message_id")
            let chatId: Int = try! map.value("audio.chat_id")
            self = .audio(link, orig, messageId, chatId)
        } else {
            throw MapError(key: "data", currentValue: (map.value() as [String: Any]?), reason: "Unknown content type")
        }
    }
    
    mutating func mapping(map: Map) {
    }
}
