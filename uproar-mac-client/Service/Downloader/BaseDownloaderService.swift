//
//  BaseDownloaderService.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 07.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Foundation

class BaseDownloaderService {
    internal lazy var appSupportUrl: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("uproar-mac")
    }()
}
