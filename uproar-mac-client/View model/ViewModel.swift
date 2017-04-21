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
    
    private let dependencies = AppDependency()
    
    private lazy var trackQueueManager: TrackQueueManager = { TrackQueueManager(dependencies: self.dependencies) }()
    
    private let currentTrack: Atomic<PlayerAssetBasedTrack?> = Atomic(nil)
    
    let playNextAction: Action<(), (), NoError> = Action { SignalProducer(value: $0) }
    private(set) lazy var nextTrackAssetSignalProducer: SignalProducer<AVURLAsset, NoError> = self.nextTrackAsset()
    
    lazy private(set) var loadedSignal: Signal<(), NoError> = { self.dependencies.uproarClient.connectedSignal.take(first: 1) }()
    
    override init() {
        super.init()
        
        SignalProducer(dependencies.uproarClient.updateSignal)
            .flatMap(.merge) {[weak self] (update) -> SignalProducer<UproarContent, NoError> in
                guard let strongSelf = self else {
                    return SignalProducer.empty
                }
                
                switch update {
                case .addContent(let content):
                    return strongSelf.trackQueueManager.enqueueTrackAction.apply(content).ignoreErrors()
                case .skip(let orig):
                    let currentTrack: PlayerAssetBasedTrack? = (strongSelf.currentTrack.modify { track in
                        guard let currentTrackValue = track, currentTrackValue.orig == orig else {
                            return nil
                        }
                        strongSelf.dependencies.uproarClient.update(status: .skip(currentTrackValue.orig, currentTrackValue.messageId, currentTrackValue.chatId)).start()
                        track = nil
                        return currentTrackValue
                    })
                    if currentTrack != nil {
                        return strongSelf.playNextAction.apply(())
                            .flatMap(.latest) { SignalProducer<UproarContent, NoError>.empty }
                            .ignoreErrors()
                    } else {
                        return strongSelf.trackQueueManager.skipTrackAction.apply(orig)
                            .flatMap(.latest) { _ in SignalProducer<UproarContent, NoError>.empty }
                            .ignoreErrors()
                    }
                }
            }
            .start()
    }
    
    private func nextTrackAsset() -> SignalProducer<AVURLAsset, NoError> {
        return SignalProducer(playNextAction.values)
            .flatMap(.latest) {[weak self] _ -> SignalProducer<AVURLAsset, NoError> in
                guard let strongSelf = self else {
                    return SignalProducer.empty
                }
                
                if let prevTrack = strongSelf.currentTrack.swap(nil) {
                    strongSelf.dependencies.uproarClient.update(status: .done(prevTrack.orig, prevTrack.messageId, prevTrack.chatId)).start()
                }
                
                return strongSelf.trackQueueManager.dequeueNextTrackAction.apply()
                    .flatMap(.latest) { track -> SignalProducer<AVURLAsset, ActionError<TrackQueueError>> in
                        guard let strongSelf = self else {
                            return SignalProducer.empty
                        }
                        
                        let playNextSignalProducer = SignalProducer(value: ())
                            .delay(10.0, on: QueueScheduler.main)
                            .flatMap(.latest) { _ in strongSelf.playNextAction.apply() }
                            .flatMap(.latest) { _ in SignalProducer<AVURLAsset, NoError>.empty
                            }.flatMapError { _ -> SignalProducer<AVURLAsset, ActionError<TrackQueueError>> in
                                SignalProducer<AVURLAsset, ActionError<TrackQueueError>>.empty
                        }
                        
                        // TODO: play PlayerUrlBasedTrack
                        guard let assetBasedTrack = track as? PlayerAssetBasedTrack else {
                            strongSelf.dependencies.uproarClient.update(status: .skip(track.orig, track.messageId, track.chatId)).start()
                            return playNextSignalProducer
                        }
                        
                        do {
                            try strongSelf.validate(asset: assetBasedTrack.asset)
                            strongSelf.currentTrack.value = assetBasedTrack
                            strongSelf.dependencies.uproarClient.update(status: .playing(track.orig, track.messageId, track.chatId)).start()
                            
                            return SignalProducer(value: assetBasedTrack.asset)
                        } catch AssetError.failedKey(let key, let error) {
                            let stringFormat = NSLocalizedString("error.asset_key_%@_failed.description", comment: "Can't use this AVAsset because one of it's keys failed to load")
                            let message = String.localizedStringWithFormat(stringFormat, key)
                            strongSelf.handleErrorWithMessage(message, error: error)
                            strongSelf.dependencies.uproarClient.update(status: .skip(track.orig, track.messageId, track.chatId)).start()
                            return playNextSignalProducer
                        } catch AssetError.notPlayable {
                            let message = NSLocalizedString("error.asset_not_playable.description", comment: "Can't use this AVAsset because it isn't playable or has protected content")
                            strongSelf.handleErrorWithMessage(message)
                            strongSelf.dependencies.uproarClient.update(status: .skip(track.orig, track.messageId, track.chatId)).start()
                            return playNextSignalProducer
                        } catch {
                            strongSelf.dependencies.uproarClient.update(status: .skip(track.orig, track.messageId, track.chatId)).start()
                            return playNextSignalProducer
                        }
                    }.flatMapError { error in
                        guard let strongSelf = self else {
                            return SignalProducer.empty
                        }
                        
                        // TODO: check error
                        
                        strongSelf.dependencies.uproarClient.send(message: UproarMessage.boring(Constants.token)).start()
                        return SignalProducer(value: ())
                            .delay(20.0, on: QueueScheduler.main)
                            .flatMap(.latest) { _ in strongSelf.playNextAction.apply(()) }
                            .flatMap(.latest) { _ in SignalProducer<AVURLAsset, NoError>.empty }
                            .ignoreErrors()
                        
                }
        }
    }
    
    private func validate(asset: AVURLAsset) throws {
        for key in Constants.assetKeysRequiredToPlay {
            var error: NSError?
            if asset.statusOfValue(forKey: key, error: &error) == .failed {
                throw AssetError.failedKey(key, error)
            }
        }
        
        if !asset.isPlayable /*|| asset.hasProtectedContent*/ {
            throw AssetError.notPlayable
        }
    }
    
    private func handleErrorWithMessage(_ message: String?, error: Error? = nil) {
        print("Error occured with message: \(String(describing: message)), error: \(String(describing: error?.localizedDescription)).")
    }
}
