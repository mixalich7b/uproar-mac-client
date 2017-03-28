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

class ViewController: NSViewController {
    
    @objc private let player = AVPlayer()
    
    @IBOutlet var viewModel: ViewModel!
    
    private lazy var playerItemStatusProperty: DynamicProperty<Int> = {
        DynamicProperty(object: self, keyPath: #keyPath(ViewController.player.currentItem.status))
    }()
    private var playerItemStatusDisposable: Disposable?
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        if let playerView = self.view as? PlayerView {
            playerView.player = player
        }
        
        self.playerItemStatusDisposable = playerItemStatusProperty.signal.observeValues {[weak self] playerItemStatus in
            let newStatus: AVPlayerItemStatus = playerItemStatus.flatMap { AVPlayerItemStatus(rawValue: $0) } ?? .unknown
            
            guard let strongSelf = self else {
                return
            }
            switch newStatus {
            case .failed:
                strongSelf.handleErrorWithMessage(strongSelf.player.currentItem?.error?.localizedDescription, error:strongSelf.player.currentItem?.error)
                break
            case .readyToPlay:
                break
            default:
                break
            }
        }
        
        player.play()
        
        viewModel.nextVideoAsset.startWithValues {[weak self] (asset) in
            let playerItem = AVPlayerItem(asset: asset)
            self?.player.replaceCurrentItem(with: playerItem)
        }
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        player.pause()
        
        self.playerItemStatusDisposable?.dispose()
    }
    
    private func handleErrorWithMessage(_ message: String?, error: Error? = nil) {
        print("Error occured with message: \(message), error: \(error).")
    }
}

