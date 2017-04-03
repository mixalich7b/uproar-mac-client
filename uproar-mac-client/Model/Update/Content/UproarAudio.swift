//
//  UproarAudio.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 03.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import ObjectMapper

class UproarAudio: UproarContent, ImmutableMappable {
    required init(map: Map) throws {
        let urlString: String = try! map.value("audio.track_url")
        let orig: Int = try! map.value("audio.orig")
        let messageId: Int = try! map.value("audio.message_id")
        let chatId: Int = try! map.value("audio.chat_id")
        
        super.init(urlString: urlString, orig: orig, messageId: messageId, chatId: chatId)
    }
}
