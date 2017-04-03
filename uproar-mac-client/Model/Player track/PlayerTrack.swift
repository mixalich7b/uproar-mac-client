//
//  PlayerTrack.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 03.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Foundation

class PlayerTrack {
    let orig: Int
    let messageId: Int
    let chatId: Int
    
    init(orig: Int, messageId: Int, chatId: Int) {
        self.orig = orig
        self.messageId = messageId
        self.chatId = chatId
    }
}
