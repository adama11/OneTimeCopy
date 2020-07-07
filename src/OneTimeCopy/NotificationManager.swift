//
//  NotificationManager.swift
//  OneTimeCopy
//
//  Created by Adam Dama on 7/4/20.
//  Copyright © 2020 Adam Dama. All rights reserved.
//

import Cocoa
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    
    var notificationCenter : UNUserNotificationCenter!
    let appDelegate = NSApplication.shared.delegate as! AppDelegate
        
    override init() {
        super.init()
        notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.delegate = self
        setUp()
    }
    
    private func setUp() {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                // Handle the error here.
                print("Error setting up notifcations: \(error)")
            }
            // Enable or disable features based on the authorization.
        }
        
        // Define the custom actions.
        let copyAction = UNNotificationAction(identifier: "COPY_ACTION", title: "Copy", options: UNNotificationActionOptions(rawValue: 0))
        let closeAction = UNNotificationAction(identifier: "CLOSE_ACTION", title: "Close", options: UNNotificationActionOptions(rawValue: 0))
        // Define the notification type
        let newCodeCategory = UNNotificationCategory(identifier: "NEW_CODE", actions: [closeAction, copyAction], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: "", options: .customDismissAction)
        
        // Register the notification type.
        notificationCenter.setNotificationCategories([newCodeCategory])

    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {

        // Get the codefrom the original notification.
        let userInfo = response.notification.request.content.userInfo
        let code = userInfo["CODE"] as! String

        // Perform the task associated with the action.
        switch response.actionIdentifier {
        case "COPY_ACTION":
            appDelegate.processor.copyToClipboard(code)
        // Handle other actions…
        default:
            break
        }

        // Always call the completion handler when done.
        completionHandler()
    }
    
    func showCodeNotification(_ data: (score: Int, code: String, date: Date)) -> Void {
        let content = UNMutableNotificationContent()
        content.title = "You have a new code!"
        
        content.subtitle = "\(data.code)"
        if let autoCopy = appDelegate.getPref(forKey: "auto_copy") {
            if autoCopy {
                content.body = "Copied to your clipboard"
            }
        }
            
        content.categoryIdentifier = "NEW_CODE"
        content.userInfo = ["CODE" : data.code]
        
        if let useSound = appDelegate.getPref(forKey: "notification_sound") {
            if useSound {
                content.sound = UNNotificationSound(named: UNNotificationSoundName("onetimecopy_notif_sound"))
            }
        }
        
        let request = UNNotificationRequest(identifier: UUID.init().uuidString, content: content, trigger: nil)

        notificationCenter.add(request)
    }
    

}



