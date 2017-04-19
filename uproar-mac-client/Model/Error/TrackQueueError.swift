//
//  TrackQueueError.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 19.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Cocoa

enum TrackQueueError: Error {
    case trackNotFound(String)
    case emptyQueue(String)
}
