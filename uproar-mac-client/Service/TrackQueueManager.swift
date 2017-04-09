//
//  TrackQueueManager.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 08.04.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import ReactiveSwift
import Result
import AVFoundation

class TrackQueueManager {
    
    lazy private(set) var enqueueTrackAction: Action<UproarContent, (), NoError> = self.enqueueTrack()
    lazy private(set) var skipTrackAction: Action<Int, UproarContent?, NoError> = self.skipTrack()
    
    private let downloadQueue = Atomic<[UproarContent]>([])
    private let playQueue = Atomic<[PlayerTrack]>([])
    
    private let currentDownloading: Atomic<UproarContent?> = Atomic(nil)
    
    private let youtubeDownloaderService = YoutubeDownloaderService()
    private let fileDownloaderService = FileDownloaderService()
    
    init() {
        
    }
    
    private func enqueueTrack() -> Action<UproarContent, (), NoError> {
        return Action {[weak self] content in
            return SignalProducer(value: ()).on(value: { _ in
                self?.addToDownloadQueue(content)
            })
        }
    }
    
    private func skipTrack() -> Action<Int, UproarContent?, NoError> {
        return Action {[weak self] (orig) -> SignalProducer<UproarContent?, NoError> in
            return SignalProducer { (observer, disposable) -> Void in
                defer {
                    observer.sendCompleted()
                }
                guard let strongSelf = self else {
                    return
                }
                
                if let content: UproarContent = (strongSelf.currentDownloading.modify { current in
                    if current?.orig ?? 0 == orig {
                        let oldValue = current
                        current = nil
                        return oldValue
                    } else {
                        return nil
                    }
                }) {
                    observer.send(value: content)
                } else if let content: UproarContent = (strongSelf.downloadQueue.modify { queue in
                    return queue.pullFirst { $0.orig == orig }
                }) {
                    observer.send(value: content)
                } else {
                    strongSelf.handleErrorWithMessage("Content with orig \(orig) not found")
                    
                    observer.send(value: nil)
                }
            }
        }
    }
    
    private func downloadNext() -> Signal<PlayerTrack, NoError> {
        return Signal {[weak self] (observer: Observer<UproarContent, NoError>) -> Disposable? in
            guard let strongSelf = self else {
                observer.sendCompleted()
                return nil
            }
            guard let content = (strongSelf.pollFromDownloadQueue { self?.currentDownloading.value = $0 }) else {
                observer.sendCompleted()
                return nil
            }
            
            observer.send(value: content)
            observer.sendCompleted()
            
            return nil
        }.flatMap(.latest) {[weak self] (content) -> Signal<PlayerTrack, NoError> in
            guard let strongSelf = self else {
                return Signal.empty
            }
            
            guard let url = URL(string: content.urlString) else {
                return Signal.empty
            }
            
            let contentMapping: (URL) -> Signal<PlayerTrack, DownloadingError> = { (localContentUrl) in
                let asset = AVURLAsset(url: localContentUrl)
                return Signal { (observer) -> Disposable? in
                    asset.loadValuesAsynchronously(forKeys: Constants.assetKeysRequiredToPlay) {
                        let playerTrack = PlayerAssetBasedTrack(asset: asset, orig: content.orig, messageId: content.messageId, chatId: content.chatId)
                        
                        observer.send(value: playerTrack)
                        observer.sendCompleted()
                    }
                    return nil
                }
            }
            
            let contentLoadingErrorMapping: (DownloadingError) -> SignalProducer<PlayerTrack, NoError> = { error in
                self?.handleErrorWithMessage("Content is not loaded", error: error)
                
                return SignalProducer(value: PlayerUrlBasedTrack(url: url, orig: content.orig, messageId: content.messageId, chatId: content.chatId))
            }
            
            switch content {
            case _ as UproarYoutubeVideo:
                return strongSelf.youtubeDownloaderService.download(by: url)
                    .flatMap(.latest, transform: contentMapping)
                    .flatMapError(contentLoadingErrorMapping)
            case _ as UproarAudio:
                return strongSelf.fileDownloaderService.download(by: url)
                    .flatMap(.latest, transform: contentMapping)
                    .flatMapError(contentLoadingErrorMapping)
            default:
                assertionFailure("Unsupported content type")
                return Signal.empty
            }
        }
    }
    
    private func addToDownloadQueue(_ content: UproarContent) {
        self.downloadQueue.modify { queue in
            queue.append(content)
        }
    }
    
    private func pollFromDownloadQueue(_ action: ((UproarContent?) -> Void)? = nil) -> UproarContent? {
        return self.downloadQueue.modify { queue -> UproarContent? in
            
            let first = queue.first
            if first != nil {
                queue.removeFirst()
            }
            
            action?(first)
            
            return first
        }
    }
    
    private func handleErrorWithMessage(_ message: String?, error: Error? = nil) {
        print("Error occured with message: \(String(describing: message)), error: \(String(describing: error?.localizedDescription)).")
    }
}
