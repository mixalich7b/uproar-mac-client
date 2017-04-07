//
//  DownloadingError.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 28.03.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Foundation

struct DownloadingError: LocalizedError {
    let message: String
    
    var errorDescription: String? {
        get {
            return message
        }
    }
}
