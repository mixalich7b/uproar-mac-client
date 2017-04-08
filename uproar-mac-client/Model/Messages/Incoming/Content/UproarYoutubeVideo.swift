//
//  UproarYoutubeVideo.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 03.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import ObjectMapper

class UproarYoutubeVideo: UproarContent, ImmutableMappable {
    required init(map: Map) throws {
        let urlString: String = try! map.value("youtube_link.url")
        let orig: Int = try! map.value("youtube_link.orig")
        let messageId: Int = try! map.value("youtube_link.message_id")
        let chatId: Int = try! map.value("youtube_link.chat_id")
        
        super.init(urlString: urlString, orig: orig, messageId: messageId, chatId: chatId)
    }
}
