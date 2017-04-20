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
    
    typealias Dependencies = HasUproarClient & HasYoutubeDownloaderService & HasFileDownloaderService
    
    lazy private(set) var enqueueTrackAction: Action<UproarContent, UproarContent, NoError> = self.enqueueTrack()
    lazy private(set) var skipTrackAction: Action<Int, UproarContent, TrackQueueError> = self.skipTrack()
    lazy private(set) var dequeueNextTrackAction: Action<(), PlayerTrack, TrackQueueError> = self.dequeueNextTrack()
    
    private let downloadQueue = Atomic<[UproarContent]>([])
    private let playQueue = Atomic<[PlayerTrack]>([])
    
    private let currentDownloading: Atomic<UproarContent?> = Atomic(nil)
    private let downloadingDisposable = SerialDisposable()
    
    private let dependencies: Dependencies
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        
        restartDownloading()
        
        skipTrackAction.values
            .flatMap(.latest) {[weak self] (skippedContent) -> SignalProducer<(), AnyError> in
                guard let strongSelf = self else {
                    return SignalProducer.empty
                }
                return strongSelf.dependencies.uproarClient.update(status: .skip(skippedContent.orig, skippedContent.messageId, skippedContent.chatId))
            }
            .ignoreErrors()
            .observe(.init())
    }
    
    private func restartDownloading() {
        downloadingDisposable.inner = downloadNext().start()
    }
    
    private func enqueueTrack() -> Action<UproarContent, UproarContent, NoError> {
        return Action {[weak self] content in
            return SignalProducer({ (observer, _) in
                guard let strongSelf = self else {
                    observer.sendCompleted()
                    return
                }
                strongSelf.add(content: content, toQueue: strongSelf.downloadQueue)
                observer.send(value: content)
                observer.sendCompleted()
            })
        }
    }
    
    private func skipTrack() -> Action<Int, UproarContent, TrackQueueError> {
        return Action {[weak self] (orig) -> SignalProducer<UproarContent, TrackQueueError> in
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
                        self?.restartDownloading()
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
                    
                    observer.send(error: .trackNotFound("Content with orig \(orig) not found"))
                }
            }
        }
    }
    
    private func dequeueNextTrack() -> Action<(), PlayerTrack, TrackQueueError> {
        return Action {[weak self] _ -> SignalProducer<PlayerTrack, TrackQueueError> in
            guard let strongSelf = self else {
                return SignalProducer.empty
            }
            guard let content = (strongSelf.pollFromQueue(strongSelf.playQueue)) else {
                return SignalProducer.init(error: .emptyQueue("playQueue is empty"))
            }
            
            return SignalProducer(value: content)
        }
    }
    
    // recursive
    private func downloadNext() -> SignalProducer<PlayerTrack, NoError> {
        let waitForContent = self.downloadQueue.value.count > 0 ?
            SignalProducer(value: ()) : SignalProducer(self.enqueueTrackAction.values.take(first: 1)).map { _ in () }
        
        return waitForContent
            .flatMap(.latest) {[weak self] _ -> Signal<PlayerTrack, NoError> in
                guard let strongSelf = self else {
                    return Signal.empty
                }
                guard let content = (strongSelf.pollFromQueue(strongSelf.downloadQueue) { self?.currentDownloading.value = $0 }) else {
                    return Signal.empty
                }
                
                return strongSelf.download(content)
            }.on(value: {[weak self] _ in
                self?.currentDownloading.value = nil
            }).flatMap(.latest) {[weak self] track -> SignalProducer<PlayerTrack, NoError> in
                guard let strongSelf = self else {
                    return SignalProducer.empty
                }
                
                strongSelf.dependencies.uproarClient.update(status: .queue(track.orig, track.messageId, track.chatId)).start()
                strongSelf.add(content: track, toQueue: strongSelf.playQueue)
                return strongSelf.downloadNext()
        }
    }
    
    private func download(_ content: UproarContent) -> Signal<PlayerTrack, NoError> {
        guard let url = URL(string: content.urlString) else {
            return Signal.empty
        }
        
        self.dependencies.uproarClient.update(status: .download(content.orig, content.messageId, content.chatId)).start()
        
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
        
        let contentLoadingErrorMapping: (DownloadingError) -> SignalProducer<PlayerTrack, NoError> = {[weak self] error in
            self?.handleErrorWithMessage("Content is not loaded", error: error)
            
            return SignalProducer(value: PlayerUrlBasedTrack(url: url, orig: content.orig, messageId: content.messageId, chatId: content.chatId))
        }
        
        switch content {
        case _ as UproarYoutubeVideo:
            return self.dependencies.youtubeDownloaderService.download(by: url)
                .flatMap(.latest, transform: contentMapping)
                .flatMapError(contentLoadingErrorMapping)
        case _ as UproarAudio:
            return self.dependencies.fileDownloaderService.download(by: url)
                .flatMap(.latest, transform: contentMapping)
                .flatMapError(contentLoadingErrorMapping)
        default:
            assertionFailure("Unsupported content type")
            return Signal.empty
        }
    }
    
    private func add<Content>(content: Content, toQueue queueHolder: Atomic<[Content]>) {
        queueHolder.modify { queue in
            queue.append(content)
        }
    }
    
    private func pollFromQueue<Content>(_ queue: Atomic<[Content]>, _ action: ((Content?) -> Void)? = nil) -> Content? {
        return queue.modify { queue -> Content? in
            let first = queue.pullFirst()
            action?(first)
            return first
        }
    }
    
    private func handleErrorWithMessage(_ message: String?, error: Error? = nil) {
        print("Error occured with message: \(String(describing: message)), error: \(String(describing: error?.localizedDescription)).")
    }
}
