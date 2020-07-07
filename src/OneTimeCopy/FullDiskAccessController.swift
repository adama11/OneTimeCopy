//
//  FullDiskAccessController.swift
//  OneTimeCopy
//
//  Created by Adam Dama on 6/20/20.
//  Copyright © 2020 Adam Dama. All rights reserved.
//

import Cocoa
import SwiftUI

class FullDiskAccessController: NSObject, NSWindowDelegate {

    var popupWindow : NSWindow
    var isVisible: Bool
    
    override init() {
        isVisible = false
        let popupView = RequestFullDiskAccessView()
        popupWindow = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 600, height: 300),
                    styleMask: [.fullSizeContentView, .closable, .titled],
                    backing: .buffered, defer: false)
        popupWindow.hasShadow = true
        popupWindow.center()
        popupWindow.setFrameAutosaveName("Allow Full Disk Access: OneTimeCopy")
        popupWindow.contentView = NSHostingView(rootView: popupView)
        popupWindow.titleVisibility = .visible
        popupWindow.titlebarAppearsTransparent = true
        
        super.init()
        popupWindow.delegate = self
    }
    
    func windowWillClose(_ notification: Notification) {
        isVisible = false
    }
    
    func getAccess() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let path = homeDir.appendingPathComponent("Library/Messages/").absoluteURL
        do {
            try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil, options: [])
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == 257 {
            print(error.localizedDescription)
            if !(isVisible) {
                self.popupWindow.setIsVisible(true)
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
}
