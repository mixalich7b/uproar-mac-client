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
    
//    private let uproarClient = UproarClient()
    
    private let youtubeLoaderService = YoutubeLoaderService()
    
    private var videoAssetsQueue = [AVURLAsset]()
    
    private lazy var enqueueAsset: Action<AVURLAsset, (), NoError> = self.createEnqueueAssetAction()
    private(set) lazy var playNext: Action<(), (), NoError> = { Action { SignalProducer(value: $0) } }()
    private(set) lazy var nextVideoAsset: SignalProducer<AVURLAsset, NoError> = self.createNextVideoAssetSignalProducer()
    
    override init() {
        super.init()
        
        SignalProducer(value: "https://www.youtube.com/watch?v=doAcaKGeQwI")
            .flatMap(.merge, transform: download)
            .observe(on: UIScheduler())
            .start(handleAssetEvent)
    }
    
    private func createEnqueueAssetAction() -> Action<AVURLAsset, (), NoError> {
        return Action {[weak self] (asset) -> SignalProducer<(), NoError> in
            guard let strongSelf = self else {
                return SignalProducer.empty
            }
            
            strongSelf.videoAssetsQueue.append(asset)
            return SignalProducer(value: ())
        }
    }
    
    private func createNextVideoAssetSignalProducer() -> SignalProducer<AVURLAsset, NoError> {
        return SignalProducer(value: ())
            .concat(SignalProducer(playNext.values))
            .flatMap(.latest) {[weak self] _ -> SignalProducer<AVURLAsset, NoError> in
                guard let strongSelf = self else {
                    return SignalProducer.empty
                }
                
                let waitAsset = strongSelf.videoAssetsQueue.isEmpty ? SignalProducer(strongSelf.enqueueAsset.values.take(first: 1)) : SignalProducer(value: ())
                return waitAsset.flatMap(.latest) { _ -> SignalProducer<AVURLAsset, NoError> in
                    guard let strongSelf = self else {
                        return SignalProducer.empty
                    }
                    
                    return SignalProducer(value: strongSelf.videoAssetsQueue.removeFirst())
                }
        }
    }
    
    private func download(_ urlString: String) -> Signal<AVURLAsset, YoutubeLoadingError> {
        return self.youtubeLoaderService.downloadVideo(by: URL(string: urlString)!)
            .flatMap(.latest) { (localVideoUrl) -> Signal<AVURLAsset, YoutubeLoadingError> in
                let asset = AVURLAsset(url: localVideoUrl)
                return Signal { (observer) -> Disposable? in
                    asset.loadValuesAsynchronously(forKeys: ViewModel.assetKeysRequiredToPlay) {
                        observer.send(value: asset)
                    }
                    return nil
                }
        }
    }
    
    private func handleAssetEvent(_ event: Event<AVURLAsset, YoutubeLoadingError>) {
        switch event {
        case .value(let loadedAsset):
            do {
                try validate(asset: loadedAsset)
                enqueueAsset.apply(loadedAsset).start()
            } catch AssetError.failedKey(let key, let error) {
                let stringFormat = NSLocalizedString("error.asset_key_%@_failed.description", comment: "Can't use this AVAsset because one of it's keys failed to load")
                let message = String.localizedStringWithFormat(stringFormat, key)
                handleErrorWithMessage(message, error: error)
                
            } catch AssetError.notPlayable {
                let message = NSLocalizedString("error.asset_not_playable.description", comment: "Can't use this AVAsset because it isn't playable or has protected content")
                handleErrorWithMessage(message)
            } catch {
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
        print("Error occured with message: \(message), error: \(error).")
    }
}