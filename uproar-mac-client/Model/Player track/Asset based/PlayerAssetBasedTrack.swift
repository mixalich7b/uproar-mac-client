//
//  PlayerAssetBasedTrack.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 03.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import AVFoundation

class PlayerAssetBasedTrack: PlayerTrack {
    let asset: AVURLAsset
    
    init(asset: AVURLAsset, orig: Int, messageId: Int, chatId: Int) {
        self.asset = asset
        super.init(orig: orig, messageId: messageId, chatId: chatId)
    }
}
