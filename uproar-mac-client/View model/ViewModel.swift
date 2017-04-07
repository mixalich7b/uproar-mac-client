//
//  ViewModel.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 10.03.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import ReactiveSwift
import SwiftMQTT
import AVFoundation
import Result

class ViewModel: NSObject {
    
    private static let assetKeysRequiredToPlay = [
        "playable",
        "hasProtectedContent"
    ]
    
    private let youtubeDownloaderService = YoutubeDownloaderService()
    private let fileDownloaderService = FileDownloaderService()
    private let uproarClient = UproarClient()
    
    private var playerTrackQueue = [PlayerAssetBasedTrack]()
    private let lastDequeued: Atomic<PlayerAssetBasedTrack?> = Atomic(nil)
    
    private lazy var enqueueTrackAction: Action<PlayerAssetBasedTrack, (), NoError> = self.enqueueTrack()
    private(set) lazy var playNextAction: Action<(), (), NoError> = { Action { SignalProducer(value: $0) } }()
    private(set) lazy var nextVideoAssetSignalProducer: SignalProducer<AVURLAsset, NoError> = self.nextVideoAsset()
    
    override init() {
        super.init()
        
        SignalProducer(uproarClient.updateSignal)
            .filterMap { update -> UproarContent? in
                switch update {
                case .addContent(let content): return content
                }
            }
            .flatMap(.merge, transform: download)
            .start(handleTrack)
    }
    
    private func enqueueTrack() -> Action<PlayerAssetBasedTrack, (), NoError> {
        return Action {[weak self] (playerTrack) -> SignalProducer<(), NoError> in
            guard let strongSelf = self else {
                return SignalProducer.empty
            }
            if !strongSelf.playerTrackQueue.contains(where: { $0.asset.url == playerTrack.asset.url }) {
                strongSelf.playerTrackQueue.append(playerTrack)
            }
            strongSelf.update(status: .queue(playerTrack.orig, playerTrack.messageId, playerTrack.chatId))
            return SignalProducer(value: ())
        }
    }
    
    private func nextVideoAsset() -> SignalProducer<AVURLAsset, NoError> {
        return SignalProducer(playNextAction.values)
            .flatMap(.latest) {[weak self] _ -> SignalProducer<AVURLAsset, NoError> in
                guard let strongSelf = self else {
                    return SignalProducer.empty
                }
                
                if let prevTrack = strongSelf.lastDequeued.value {
                    strongSelf.update(status: .done(prevTrack.orig, prevTrack.messageId, prevTrack.chatId))
                }
                
                let waitAsset = strongSelf.playerTrackQueue.isEmpty ? SignalProducer(strongSelf.enqueueTrackAction.values.take(first: 1)) : SignalProducer(value: ())
                return waitAsset.flatMap(.latest) { _ -> SignalProducer<AVURLAsset, NoError> in
                    guard let strongSelf = self else {
                        return SignalProducer.empty
                    }
                    
                    let playerTrack = strongSelf.playerTrackQueue.removeFirst()
                    strongSelf.lastDequeued.value = playerTrack
                    strongSelf.update(status: .playing(playerTrack.orig, playerTrack.messageId, playerTrack.chatId))
                    return SignalProducer(value: playerTrack.asset)
                }
        }
    }
    
    private func download(_ content: UproarContent) -> Signal<PlayerAssetBasedTrack, NoError> {
        self.update(status: .download(content.orig, content.messageId, content.chatId))
        
        let contentMapping: (URL) -> Signal<PlayerAssetBasedTrack, DownloadingError> = { (localContentUrl) in
            let asset = AVURLAsset(url: localContentUrl)
            return Signal { (observer) -> Disposable? in
                asset.loadValuesAsynchronously(forKeys: ViewModel.assetKeysRequiredToPlay) {
                    let playerTrack = PlayerAssetBasedTrack(asset: asset, orig: content.orig, messageId: content.messageId, chatId: content.chatId)
                    
                    observer.send(value: playerTrack)
                    observer.sendCompleted()
                }
                return nil
            }
        }
        
        let contentLoadingErrorMapping: (DownloadingError) -> SignalProducer<PlayerAssetBasedTrack, NoError> = {[weak self] error in
            self?.handleErrorWithMessage("Content is not loaded", error: error)
            
            // TODO: map to PlayerUrlBasedTrack
            return SignalProducer.empty
        }
        
        switch content {
        case let video as UproarYoutubeVideo:
            return self.youtubeDownloaderService.download(by: URL(string: video.urlString)!)
                .flatMap(.latest, transform: contentMapping)
                .flatMapError(contentLoadingErrorMapping)
        case let audio as UproarAudio:
            return self.fileDownloaderService.download(by: URL(string: audio.urlString)!)
                .flatMap(.latest, transform: contentMapping)
                .flatMapError(contentLoadingErrorMapping)
        default:
            assertionFailure("Unsupported content type")
            return Signal.empty
        }
    }
    
    private func handleTrack(_ event: Event<PlayerAssetBasedTrack, NoError>) {
        switch event {
        case .value(let playerTrack):
            do {
                try validate(asset: playerTrack.asset)
                enqueueTrackAction.apply(playerTrack).start()
            } catch AssetError.failedKey(let key, let error) {
                let stringFormat = NSLocalizedString("error.asset_key_%@_failed.description", comment: "Can't use this AVAsset because one of it's keys failed to load")
                let message = String.localizedStringWithFormat(stringFormat, key)
                handleErrorWithMessage(message, error: error)
                self.update(status: .skip(playerTrack.orig, playerTrack.messageId, playerTrack.chatId))
            } catch AssetError.notPlayable {
                let message = NSLocalizedString("error.asset_not_playable.description", comment: "Can't use this AVAsset because it isn't playable or has protected content")
                handleErrorWithMessage(message)
                self.update(status: .skip(playerTrack.orig, playerTrack.messageId, playerTrack.chatId))
            } catch {
                self.update(status: .skip(playerTrack.orig, playerTrack.messageId, playerTrack.chatId))
            }
            break
        default:
            print("Something went wrong")
            break
        }
    }
    
    private func validate(asset: AVURLAsset) throws {
        for key in ViewModel.assetKeysRequiredToPlay {
            var error: NSError?
            if asset.statusOfValue(forKey: key, error: &error) == .failed {
                throw AssetError.failedKey(key, error)
            }
        }
        
        if !asset.isPlayable || asset.hasProtectedContent {
            throw AssetError.notPlayable
        }
    }
    
    private func handleErrorWithMessage(_ message: String?, error: Error? = nil) {
        print("Error occured with message: \(String(describing: message)), error: \(String(describing: error?.localizedDescription)).")
    }
    
    private func update(status: UproarTrackStatus) {
        self.uproarClient.send(message: .trackStatus(status, Constants.token)).start()
    }
}
