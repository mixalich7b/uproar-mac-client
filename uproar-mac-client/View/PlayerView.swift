//
//  PlayerView.swift
//  uproar-mac-client
//
//  Created by Тупицин Константин on 15.03.17.
//  Copyright © 2017 mixalich7b. All rights reserved.
//

import Cocoa
import AVFoundation

class PlayerView: NSView {

    private lazy var playerLayer: AVPlayerLayer = self.createPlayerLayer()
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        
        set {
            playerLayer.player = newValue
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        self.wantsLayer = true
    }
    
    private func addPlayerLayer() {
        guard let layer = self.layer else {
            return
        }
        playerLayer.frame = layer.bounds
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer.addSublayer(playerLayer)
    }
    
    private func createPlayerLayer() -> AVPlayerLayer {
        return AVPlayerLayer()
    }
    
    override func viewDidMoveToSuperview() {
        if self.superview != nil {
            addPlayerLayer()
        } else {
            playerLayer.removeFromSuperlayer()
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        NSRectFillUsingOperation(dirtyRect, .sourceOver)
        
        super.draw(dirtyRect)
    }
}
