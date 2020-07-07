//
//  ContentView.swift
//  OneTimeCopy
//
//  Created by Adam Dama on 6/14/20.
//  Copyright © 2020 Adam Dama. All rights reserved.
//

import SwiftUI

struct RequestFullDiskAccessView: View {
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Image("hero_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 500)
                .padding(15)
            Text("Welcome!")
                .font(.title)
                .bold()
                .frame(maxWidth: .infinity)
                .padding(.bottom, 5)
                .lineLimit(nil)
            Text("This application needs access to your Messages transcripts. Your security and privacy are both very important to us. This application never stores or transmits any of your transcripts or any other personal information.")
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .lineLimit(10)
            Text("Please enable Full Disk Access for OneTimeCopy in System Preferences.")
                .font(.system(size: 15))
                .bold()
                .frame(maxWidth: .infinity)
                .padding(.bottom, 5)
                .lineLimit(nil)
            
            HStack(alignment: .center, spacing: 20.0) {
                Image("system-preferences-icon-80")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                Text("⮕")
                    .font(.system(size: 20))
                    .bold()
                Image("security-preferences-icon-80")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 35)
                Text("⮕")
                    .font(.system(size: 20))
                    .bold()
                
                ZStack() {
                    Rectangle()
                        .foregroundColor(Color.gray)
                    Text("Privacy")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white)
                        .baselineOffset(2)
                }
                .frame(width: 80, height: 20)
                    .cornerRadius(5)
                Text("⮕")
                    .font(.system(size: 20))
                    .bold()
                HStack(alignment: .center, spacing: 5) {
                    Image("blue-folder-icon-80")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 35)
                    Text("Full Disk Access")
                        .font(.system(size: 15))
                        .lineLimit(nil)
                    
                }
                    .padding(10)
                    .fixedSize(horizontal: true, vertical: false)
                
            }
            
            Button(action: {
                self.openSecurityPreferences()
            }) {
                Text("Open Security & Privacy Preferences")
                .frame(width: 300, height: 30)
            }.padding(10)
            .buttonStyle(CustomButtonStyle())
            .shadow(color: Color("shadowColor"), radius: 5, x: 0, y: 0)
        }
        .padding(15)
    }
    
    func openSecurityPreferences() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
    }
}




struct RequestFullDiskAccessView_Previews: PreviewProvider {
    static var previews: some View {
        RequestFullDiskAccessView()
    }
}
