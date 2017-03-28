//
//  AssetError.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 28.03.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Foundation

enum AssetError: Error {
    case failedKey(String, Error?)
    case notPlayable
}
