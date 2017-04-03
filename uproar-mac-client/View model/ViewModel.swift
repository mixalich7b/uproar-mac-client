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
    
    private let youtubeLoaderService = YoutubeLoaderService()
    private let uproarClient = UproarClient()
    
    private var videoAssetsQueue = [(AVURLAsset, Int, Int, Int)]()
    private let lastDequeued: Atomic<(AVURLAsset, Int, Int, Int)?> = Atomic(nil)
    
    private lazy var enqueueAssetAction: Action<(AVURLAsset, Int, Int, Int), (), NoError> = self.enqueueAsset()
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
            .start(handleAssetEvent)
    }
    
    private func enqueueAsset() -> Action<(AVURLAsset, Int, Int, Int), (), NoError> {
        return Action {[weak self] (asset) -> SignalProducer<(), NoError> in
            guard let strongSelf = self else {
                return SignalProducer.empty
            }
            if !strongSelf.videoAssetsQueue.contains(where: { $0.0.url == asset.0.url }) {
                strongSelf.videoAssetsQueue.append(asset)
            }
            strongSelf.update(status: .queue(asset.1, asset.2, asset.3))
            return SignalProducer(value: ())
        }
    }
    
    private func nextVideoAsset() -> SignalProducer<AVURLAsset, NoError> {
        return SignalProducer(playNextAction.values)
            .flatMap(.latest) {[weak self] _ -> SignalProducer<AVURLAsset, NoError> in
                guard let strongSelf = self else {
                    return SignalProducer.empty
                }
                
                if let prevAsset = strongSelf.lastDequeued.value {
                    strongSelf.update(status: .done(prevAsset.1, prevAsset.2, prevAsset.3))
                }
                
                let waitAsset = strongSelf.videoAssetsQueue.isEmpty ? SignalProducer(strongSelf.enqueueAssetAction.values.take(first: 1)) : SignalProducer(value: ())
                return waitAsset.flatMap(.latest) { _ -> SignalProducer<AVURLAsset, NoError> in
                    guard let strongSelf = self else {
                        return SignalProducer.empty
                    }
                    
                    let asset = strongSelf.videoAssetsQueue.removeFirst()
                    strongSelf.lastDequeued.value = asset
                    strongSelf.update(status: .playing(asset.1, asset.2, asset.3))
                    return SignalProducer(value: asset.0)
                }
        }
    }
    
    private func download(_ content: UproarContent) -> Signal<(AVURLAsset, Int, Int, Int), YoutubeLoadingError> {
        let urlString: String
        let orig: Int
        let messageId: Int
        let chatId: Int
        switch content {
        case .youtube(let _urlString, let _orig, let _messageId, let _chatId):
            urlString = _urlString
            orig = _orig
            messageId = _messageId
            chatId = _chatId
            break
        case .audio(let _urlString, let _orig, let _messageId, let _chatId):
            urlString = _urlString
            orig = _orig
            messageId = _messageId
            chatId = _chatId
            break
        }
        self.update(status: .download(orig, messageId, chatId))
        return self.youtubeLoaderService.downloadVideo(by: URL(string: urlString)!)
            .flatMap(.latest) { (localVideoUrl) -> Signal<(AVURLAsset, Int, Int, Int), YoutubeLoadingError> in
                let asset = AVURLAsset(url: localVideoUrl)
                return Signal { (observer) -> Disposable? in
                    asset.loadValuesAsynchronously(forKeys: ViewModel.assetKeysRequiredToPlay) {
                        observer.send(value: (asset, orig, messageId, chatId))
                        observer.sendCompleted()
                    }
                    return nil
                }
        }
    }
    
    private func handleAssetEvent(_ event: Event<(AVURLAsset, Int, Int, Int), YoutubeLoadingError>) {
        switch event {
        case .value(let loadedAsset):
            do {
                try validate(asset: loadedAsset.0)
                enqueueAssetAction.apply(loadedAsset).start()
            } catch AssetError.failedKey(let key, let error) {
                let stringFormat = NSLocalizedString("error.asset_key_%@_failed.description", comment: "Can't use this AVAsset because one of it's keys failed to load")
                let message = String.localizedStringWithFormat(stringFormat, key)
                handleErrorWithMessage(message, error: error)
                self.update(status: .skip(loadedAsset.1, loadedAsset.2, loadedAsset.3))
            } catch AssetError.notPlayable {
                let message = NSLocalizedString("error.asset_not_playable.description", comment: "Can't use this AVAsset because it isn't playable or has protected content")
                handleErrorWithMessage(message)
                self.update(status: .skip(loadedAsset.1, loadedAsset.2, loadedAsset.3))
            } catch {
                self.update(status: .skip(loadedAsset.1, loadedAsset.2, loadedAsset.3))
            }
            break
        case .failed(let error):
            handleErrorWithMessage("Video is not loaded", error: error)
            break
        default:
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
