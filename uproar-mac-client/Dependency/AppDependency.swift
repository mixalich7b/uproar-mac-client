//
//  AppDependency.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 14.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Cocoa

struct AppDependency: HasUproarClient, HasFileDownloaderService, HasYoutubeDownloaderService {
    let uproarClient = UproarClient()
    
    let youtubeDownloaderService = YoutubeDownloaderService()
    let fileDownloaderService = FileDownloaderService()
}
