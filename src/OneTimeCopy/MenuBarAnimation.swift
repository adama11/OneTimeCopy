//
//  MenuBarAnimation.swift
//  OneTimeCopy
//
//  Created by Adam Dama on 6/26/20.
//  Copyright © 2020 Adam Dama. All rights reserved.
//
import Foundation
import Cocoa

class MenuBarAnimation: ObservableObject {
    private var currentFrame = 0
    private var animTimer : Timer
    private var statusBarItem: NSStatusItem!
    private var imageNamePattern: String!
    private var imageCount : Int!

    init(statusBarItem: NSStatusItem!, imageNamePattern: String, imageCount: Int) {
        self.animTimer = Timer.init()
        self.statusBarItem = statusBarItem
        self.imageNamePattern = imageNamePattern
        self.imageCount = imageCount
    }

    func animate(withDuration: Double? = nil) {
        stop()
        currentFrame = 1
        animTimer = Timer.scheduledTimer(timeInterval: 1.0 / 30.0, target: self, selector: #selector(self.updateImage(_:)), userInfo: nil, repeats: true)
        if withDuration != nil {
            let _ = Timer.scheduledTimer(timeInterval: withDuration!, target: self, selector: #selector(self.stop), userInfo: nil, repeats: false)
        }
    }

    @objc func stop() {
        animTimer.invalidate()
        DispatchQueue.main.async {
            self.statusBarItem.button?.image = NSImage(named:NSImage.Name("status-icon"))
        }
    }

    @objc private func updateImage(_ timer: Timer?) {
        setImage(frameCount: currentFrame)
        currentFrame += 1
        if currentFrame == imageCount {
            currentFrame = 1
        }
    }

    private func setImage(frameCount: Int) {
        let imagePath = "\(imageNamePattern!)\(frameCount)"
        let image = NSImage(named: NSImage.Name(imagePath))
        DispatchQueue.main.async {
            self.statusBarItem.button?.image = image
        }
    }
}
