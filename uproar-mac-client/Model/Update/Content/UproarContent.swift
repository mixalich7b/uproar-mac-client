//
//  UproarContent.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 30.03.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Cocoa
import ObjectMapper

class UproarContent: StaticMappable {
    let urlString: String
    let orig: Int
    let messageId: Int
    let chatId: Int
    
    static func objectForMapping(map: Map) -> BaseMappable? {
        if map["youtube_link"].isKeyPresent {
            return try? UproarYoutubeVideo(map: map)
        } else if map["audio"].isKeyPresent {
            return try? UproarAudio(map: map)
        } else {
            return nil
        }
    }
    
    init(urlString: String, orig: Int, messageId: Int, chatId: Int) {
        self.urlString = urlString
        self.orig = orig
        self.messageId = messageId
        self.chatId = chatId
    }
    
    func mapping(map: Map) {
    }
}
