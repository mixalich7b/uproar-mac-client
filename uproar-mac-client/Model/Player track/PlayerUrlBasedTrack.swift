//
//  PlayerUrlBasedTrack.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 03.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Cocoa

class PlayerUrlBasedTrack: PlayerTrack {
    let url: URL
    
    init(url: URL, orig: Int, messageId: Int, chatId: Int) {
        self.url = url
        super.init(orig: orig, messageId: messageId, chatId: chatId)
    }
}
