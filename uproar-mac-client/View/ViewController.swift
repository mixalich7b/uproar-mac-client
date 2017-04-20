//
//  ViewController.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 10.03.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Cocoa
import AVFoundation
import ReactiveCocoa
import ReactiveSwift
import Result

class ViewController: NSViewController {
    
    @objc private let player = AVPlayer()
    
    @IBOutlet var viewModel: ViewModel!
    
    private lazy var playerItemStatusProperty: DynamicProperty<Int> = {
        DynamicProperty(object: self, keyPath: #keyPath(ViewController.player.currentItem.status))
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let playerView = self.view as? PlayerView {
            playerView.player = player
        }
        
        playerItemStatusProperty.signal.observeValues {[weak self] playerItemStatus in
            let newStatus: AVPlayerItemStatus = playerItemStatus.flatMap { AVPlayerItemStatus(rawValue: $0) } ?? .unknown
            
            guard let strongSelf = self else {
                return
            }
            switch newStatus {
            case .failed:
                strongSelf.viewModel.playNextAction.apply(()).start()
                strongSelf.handleErrorWithMessage(strongSelf.player.currentItem?.error?.localizedDescription, error:strongSelf.player.currentItem?.error)
                break
            default:
                break
            }
        }
        
        SignalProducer(viewModel.loadedSignal)
            .delay(90.0, on: QueueScheduler.main)
            .flatMap(.latest) {[weak self] _ -> SignalProducer<(), ActionError<NoError>> in
                guard let strongSelf = self else {
                    return SignalProducer.empty
                }
                
                return strongSelf.viewModel.nextTrackAssetSignalProducer.on(
                    started: {
                        self?.viewModel.playNextAction.apply(()).start()
                },
                    value: {[weak self] (asset) in
                        let playerItem = AVPlayerItem(asset: asset)
                        self?.player.replaceCurrentItem(with: playerItem)
                        if self?.player.rate ?? 0.0 < 0.7 {
                            self?.player.play()
                        }
                })
                    .flatMap(.latest) { _ in
                        return NotificationCenter.default.reactive
                            .notifications(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime)
                            .take(first: 1)
                    }
                    .flatMap(.latest) { _ in
                        return self?.viewModel.playNextAction.apply(()) ?? SignalProducer.empty
                }
            }.start(.init())
    }
    
    private func handleErrorWithMessage(_ message: String?, error: Error? = nil) {
        print("Error occured with message: \(String(describing: message)), error: \(String(describing: error?.localizedDescription)).")
    }
    
    deinit {
        player.pause()
        NotificationCenter.default.removeObserver(self)
    }
}

