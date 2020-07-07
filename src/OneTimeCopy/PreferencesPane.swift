//
//  PreferencesPane.swift
//  OneTimeCopy
//
//  Created by Adam Dama on 7/4/20.
//  Copyright © 2020 Adam Dama. All rights reserved.
//

import SwiftUI


class PreferenceWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 300),
            styleMask: [.fullSizeContentView, .closable, .titled],
            backing: .buffered, defer: false)
        window.hasShadow = true
        window.center()
        window.setFrameAutosaveName("OneTimeCopy Preferences")
        window.contentView = NSHostingView(rootView: PreferencesPaneView())
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        
        self.init(window: window)
    }
    
    
}


struct PreferencesPaneView: View {
    @State var notificationsEnabled: Bool = UserDefaults.standard.bool(forKey: "push_notifications")
    @State var notificationSoundEnabled: Bool = UserDefaults.standard.bool(forKey: "notification_sound")
    @State var animationEnabled: Bool = UserDefaults.standard.bool(forKey: "found_animation")
    @State var autoCopyEnabled: Bool = UserDefaults.standard.bool(forKey: "auto_copy")
    @State var autoSearchEnabled: Bool = UserDefaults.standard.bool(forKey: "auto_scan")
    @State var openOnStartupEnabled: Bool = UserDefaults.standard.bool(forKey: "open_on_startup")
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5, content: {
            Text("Settings")
                .font(.title)
                .bold()
                .frame(maxWidth: .infinity)
                .padding(.bottom, 15)
            PreferenceToggle(enabled: $notificationsEnabled, key: "push_notifications")
            PreferenceToggle(enabled: $notificationSoundEnabled, key: "notification_sound")
            PreferenceToggle(enabled: $animationEnabled, key: "found_animation")
            PreferenceToggle(enabled: $autoCopyEnabled, key: "auto_copy")
            PreferenceToggle(enabled: $autoSearchEnabled, key: "auto_scan")
            PreferenceToggle(enabled: $openOnStartupEnabled, key: "open_on_startup")
           

            Spacer()
            Group(content: {
                Text("©2020 Adam Dama")
                    .opacity(0.50)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 5)
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "https://github.com/adama11/OneTimeCopy")!)
                }, label: {
                    HStack(content: {
                        Image("github_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16)
                        Text("View Project")
                            .bold()
                        })
                })
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 5)
                    .buttonStyle(PlainButtonStyle())
                HStack(alignment: .center, spacing: 5, content: {
                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "https://raw.githubusercontent.com/adama11/OneTimeCopy/master/PrivacyPolicy.txt")!)
                    }, label: {
                        Text("Privacy Policy")
                            .underline()
                            .foregroundColor(Color.blue)
                    })
                        .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        NSWorkspace.shared.open(URL(string: "https://raw.githubusercontent.com/adama11/OneTimeCopy/master/TermsAndConditions.txt")!)
                    }, label: {
                        Text("Terms & Conditions")
                            .underline()
                            .foregroundColor(Color.blue)
                    })
                        .buttonStyle(PlainButtonStyle())
                })
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 5)
                
            })
            
        })
            .padding(.vertical, 20)
            .frame(width: 425, height: 500)
        
    }
}

struct PreferenceToggle: View {
    @Binding var enabled: Bool
    
    let appDelegate = NSApplication.shared.delegate as! AppDelegate
    var label: String
    var desc: String
    var key: String
    init(enabled: Binding<Bool>, key: String) {
        self._enabled = enabled
        self.key = key
        
        switch self.key {
        case "push_notifications":
            label = "Push Notifications"
            desc = "Get a push notification when an automatic search finds a code."
        case "notification_sound":
            label = "Notification Sound"
            desc = "Enable an alert sound with the notifications."
        case "auto_copy":
            label = "Automatic Copy"
            desc = "Automatically copy the found code to the clipboard."
        case "auto_scan":
            label = "Automatic Search"
            desc = "Automatically search for new codes in incoming messages."
        case "open_on_startup":
            label = "Open on Start-up"
            desc = "Start app automatically on system start-up."
        case "found_animation":
            label = "Icon Animation"
            desc = "Play icon animation in the menu bar when a code is found."
        default:
            label = ""
            desc = ""
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 2, content: {
                Toggle(isOn: self.$enabled, label: {
                    Text(self.label)
                        .bold()
                })
                    .onReceive([self.enabled].publisher.first()) { value in
                        self.appDelegate.setPref(forKey: self.key, value: value)
                }
                
                Text(self.desc)
                    .foregroundColor(Color("searchButtonTextColor"))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .padding(.leading, 19)
            })
                .padding(.horizontal, 30)
                .frame(width: geometry.size.width, alignment: .leading)
                
        }
    }
}



struct PreferencesPaneView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesPaneView()
    }
}
