//
//  UproarTrackStatus.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 30.03.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Cocoa
import ObjectMapper

enum UproarTrackStatus: ImmutableMappable, CustomDebugStringConvertible {
    case download(Int, Int, Int)
    case queue(Int, Int, Int)
    case playing(Int, Int, Int)
    case done(Int, Int, Int)
    case skip(Int, Int, Int)
    case promote(Int, Int, Int)
    
    init(map: Map) throws {
        throw MapError(key: "message", currentValue: (map.value() as [String: Any]?), reason: "Use cases")
    }
    
    mutating func mapping(map: Map) {
        let origKey = "orig"
        let messageIdKey = "message_id"
        let chatIdKey = "chat_id"
        let statusKey = "message"
        let titleKey = "title"
        switch self {
        case .download(let orig, let messageId, let chatId):
            "download" >>> map[statusKey]
            "Downloading" >>> map[titleKey]
            orig >>> map[origKey]
            messageId >>> map[messageIdKey]
            chatId >>> map[chatIdKey]
            break
        case .queue(let orig, let messageId, let chatId):
            "queue" >>> map[statusKey]
            "Queued" >>> map[titleKey]
            orig >>> map[origKey]
            messageId >>> map[messageIdKey]
            chatId >>> map[chatIdKey]
            break
        case .playing(let orig, let messageId, let chatId):
            "playing" >>> map[statusKey]
            "Playing" >>> map[titleKey]
            orig >>> map[origKey]
            messageId >>> map[messageIdKey]
            chatId >>> map[chatIdKey]
            break
        case .done(let orig, let messageId, let chatId):
            "done" >>> map[statusKey]
            "Played" >>> map[titleKey]
            orig >>> map[origKey]
            messageId >>> map[messageIdKey]
            chatId >>> map[chatIdKey]
            break
        case .skip(let orig, let messageId, let chatId):
            "skip" >>> map[statusKey]
            "Skip" >>> map[titleKey]
            orig >>> map[origKey]
            messageId >>> map[messageIdKey]
            chatId >>> map[chatIdKey]
            break
        case .promote(let orig, let messageId, let chatId):
            "promote" >>> map[statusKey]
            "Promoted" >>> map[titleKey]
            orig >>> map[origKey]
            messageId >>> map[messageIdKey]
            chatId >>> map[chatIdKey]
            break
        }
    }
    
    var debugDescription: String {
        get {
            switch self {
            case .download(let origMessageId):
                return "\(origMessageId) to status download"
            case .queue(let origMessageId):
                return "\(origMessageId) to status queue"
            case .playing(let origMessageId):
                return "\(origMessageId) to status playing"
            case .done(let origMessageId):
                return "\(origMessageId) to status done"
            case .skip(let origMessageId):
                return "\(origMessageId) to status skip"
            case .promote(let origMessageId):
                return "\(origMessageId) to status promote"
            }
        }
    }
}
