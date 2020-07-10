//
//  AppDelegate.swift
//  OneTimeCopy
//
//  Created by Adam Dama on 6/14/20.
//  Copyright © 2020 Adam Dama. All rights reserved.
//

import Cocoa
import SwiftUI
import UserNotifications

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    var window: NSWindow!
    var popover: NSPopover!
    var diskAccessController: FullDiskAccessController!
    let statusItem = NSStatusBar.system.statusItem(withLength: 28)
    var processor : Processor!
    var iconAnimation : MenuBarAnimation!
    var notificationManager : NotificationManager!
//    var prefPane : PreferencesPane!
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set up preferences
        setUpPreferences()
        
        // Set up menu bar animation
        iconAnimation = MenuBarAnimation(statusBarItem: statusItem, imageNamePattern: "frame-", imageCount: 30)
        
        // Ensure full disk access
        diskAccessController = FullDiskAccessController()
        diskAccessController.getAccess()
        
        // Set notification manager
        notificationManager = NotificationManager()
        
        // Set up messages processor
        processor = Processor()
        
        // Initialize the main view
        let contentView = ContentView()
            .environmentObject(processor)
            .environmentObject(iconAnimation)
        
        // Create the window and set the content view.
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 150),
            styleMask: [.fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.hasShadow = true
        window.collectionBehavior = .canJoinAllSpaces
        window.setFrameAutosaveName("OneTimeCopy")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        window.setIsVisible(false)
        window.hidesOnDeactivate = true
        window.isOpaque = false
        window.backgroundColor = .clear
        
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {

        if let button = statusItem.button {
            iconAnimation.stop() // Show static imager
            button.action = #selector(togglePopoverWindow(_:))
            button.sendAction(on: [.rightMouseDown, .leftMouseDown])
            button.imageScaling = .scaleProportionallyDown
        }
        
        setUpNotificationSound()
        openOnStartup(enable: getPref(forKey: "open_on_startup") ?? true )
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        window.setIsVisible(false)
    }
    
    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil // remove menu
    }


    @objc func togglePopoverWindow(_ sender: AnyObject?) {
        let event = NSApp.currentEvent!

        if event.type == NSEvent.EventType.rightMouseDown {
            // Right click action
            createRightClickMenu()
            if let button = self.statusItem.button {
                button.performClick(nil)
            }
        } else {
            // Left click action
            if let button = self.statusItem.button {
               if window.isVisible {
                   window.setIsVisible(false)
               } else {
                   window.setIsVisible(true)
                   NSApplication.shared.activate(ignoringOtherApps: true)

                   let currentEventFrame = NSApp.currentEvent?.window?.frame
                   let xPos = CGFloat(currentEventFrame!.minX) - window.frame.width/2 + button.frame.width/2
                   let yPos = CGFloat(currentEventFrame!.maxY) - 27
                   window.setFrameTopLeftPoint(NSPoint(x: xPos, y: yPos))
                   
               }
            }
        }
        
    }
    private func createRightClickMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Quit OneTimeCopy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "v" + self.getAppVersion(), action: nil, keyEquivalent: ""))
        statusItem.menu = menu
    }
    
    private func setUpNotificationSound() {
        let fileManager = FileManager.default

        do {
            let libraryURL = fileManager.urls(for: .allLibrariesDirectory, in: .userDomainMask).first!
            let directoryURL = libraryURL.appendingPathComponent("Sounds")
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            
            let soundSourceURL = Bundle.main.url(forResource: "onetimecopy_notif_sound", withExtension: "aiff", subdirectory: "assets")!
            let soundDestURL = directoryURL.appendingPathComponent("onetimecopy_notif_sound.aiff")
            if !fileManager.fileExists(atPath: soundDestURL.path) {
                try fileManager.copyItem(at: soundSourceURL, to: soundDestURL)
            }
        }
        catch let error as NSError {
            print("Error setting up sound: \(error)")
        }
    }
    
    private func openOnStartup(enable: Bool) {
        let fileManager = FileManager.default

        do {
            let libraryURL = fileManager.urls(for: .allLibrariesDirectory, in: .userDomainMask).first!
            let directoryURL = libraryURL.appendingPathComponent("LaunchAgents")
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            
            let plistSourceURL = Bundle.main.url(forResource: "com.adamdama.OneTimeCopy", withExtension: "plist", subdirectory: "assets")!
            let plistDestURL = directoryURL.appendingPathComponent("com.adamdama.OneTimeCopy.plist")
            if !fileManager.fileExists(atPath: plistDestURL.path) {
                if enable {
                    try fileManager.copyItem(at: plistSourceURL, to: plistDestURL)
                }
            } else {
                if !enable {
                   try fileManager.removeItem(at: plistDestURL)
                }
            }
        }
        catch let error as NSError {
            print("Error Open on startup (Enable: \(enable)): \(error)")
        }
    }
    
    private func setUpPreferences() {
        let prefKeys = ["push_notifications", "notification_sound", "found_animation", "auto_copy", "auto_scan", "open_on_startup"]
        for key in prefKeys {
            if getPref(forKey: key) == nil {
                print("setting prefs")
                setPref(forKey: key, value: true)
            }
        }
    }
    
    func getPref(forKey key: String) -> Bool? {
        return UserDefaults.standard.bool(forKey: key)
    }
    
    func setPref(forKey key: String, value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
        switch key {
        case "auto_scan":
            value ? processor.startWatch() : processor.stopWatch()
        case "open_on_startup":
            openOnStartup(enable: value)
        default:
            break
        }
    }
    
    func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        } else {
            return ""
        }
    }
}

