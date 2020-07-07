//
//  ContentView.swift
//  OneTimeCopy
//
//  Created by Adam Dama on 6/14/20.
//  Copyright © 2020 Adam Dama. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @State var progressBarValue: Float = 0.0
    @State var codeText: String = "- - - - - -"
    @State var dateText: String = ""
    @State var searchButtonText: String = "Search"
    @State var canCopy: Bool = false
    @State var isLoading: Bool = false
    @State var shouldAnimateProgress: Bool = true
    @State var canOpenPref: Bool = true
    @EnvironmentObject var processor : Processor
    @EnvironmentObject var iconAnimation : MenuBarAnimation
    let appDelegate = NSApplication.shared.delegate as! AppDelegate
    let prefController = PreferenceWindowController()
    
    var body: some View {
        VStack(alignment: .center, spacing: 2, content: {
            ZStack(content: {
                DateView(date: $dateText)
                ProgressBar(value: $progressBarValue, animate: $shouldAnimateProgress)
 
                Text(codeText)
                    .font(.custom("Abel", size: 50))
                    .foregroundColor(Color.white)
                    .fontWeight(.bold)
                    .modifier(FitToContainer(fraction: 1.0))
                    .padding(10)
                    .opacity(self.isLoading ? 0 : 1)
                    .animation(.easeInOut(duration: 0.25))
                LoadingCirle(isRotating: $isLoading)
                    .opacity(self.isLoading ? 1 : 0)
                    .animation(.easeInOut(duration: 0.25))
                
            })
                .padding(.bottom, 10)
                .frame(height: 65)
            HStack(alignment: .center, spacing: 6, content: {
                Button(action: {
                    self.manualRunSearch()
                }) {
                    Text(self.searchButtonText)
                        .font(.system(size: 15))
                        .frame(width: 140, height: 30)
                }
                    .buttonStyle(CustomButtonStyle())
                    .shadow(color: Color("shadowColor"), radius: 5, x: 0, y: 0)
                    .padding(.trailing, 10)
                Button(action: {
                    self.processor.copyToClipboard(self.codeText)
                }) {
                    Image("copy_25")
                        .resizable()
                        .scaledToFit()
                        .padding(5)
                        .frame(width: 30, height: 30)
                        .opacity(canCopy ? 1.0 : 0.15)
                }
                    .buttonStyle(CustomButtonStyle())
                    .shadow(color: Color("shadowColor"), radius: 5, x: 0, y: 0)
                    .disabled(!canCopy)
                Button(action: {
                    if let visible = self.prefController.window?.isVisible {
                        if !visible {
                            print("pref open")
                            self.prefController.showWindow(nil)
                        }
                    }
                    
                }) {
                    Image("gear_25")
                        .resizable()
                        .scaledToFit()
                        .padding(5)
                        .frame(width: 30, height: 30)
                }
                    .buttonStyle(CustomButtonStyle())
                    .shadow(color: Color("shadowColor"), radius: 5, x: 0, y: 0)
                    
            })
                .padding(.top, 20)
        })
            .padding(14)
            .frame(maxWidth: 250, maxHeight: 140)
            .background(BackgroundView())
            .onReceive(processor.$dataAvailable, perform: { dataAvailable in
                if dataAvailable {
                    _ = self.processSearchResults(self.processor.recentData)
                    self.resetSearchText(delay: 5.0)
                }
            })
    
    }
    
    func reset() {
        self.shouldAnimateProgress = false
        self.progressBarValue = 0.0
        self.dateText = ""
        self.codeText = "- - - - - -"
        self.shouldAnimateProgress = true
        self.canCopy = false
    }
    
    func updateDate(to date : Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d 'at' h:mm a"
        self.dateText = formatter.string(from: date)
    }
    func processSearchResults(_ searchResult: (score: Int, code: String, date: Date)?) -> Bool {
        var areResults = false
        if let result = searchResult {
            self.codeText = result.code
            self.searchButtonText = "Copied!"
            self.canCopy = true
            self.updateDate(to: result.date)
            DispatchQueue.main.async {
                if let shouldAnimate = self.appDelegate.getPref(forKey: "found_animation") {
                    if shouldAnimate {
                        self.iconAnimation.animate(withDuration: 5.0)
                    }
                }
            }
            areResults = true
            self.progressBarValue = 1.0
        } else {
            DispatchQueue.main.async {
                self.reset()
            }
        }
        self.isLoading = false
        return areResults
    }
    func manualRunSearch() {
        self.reset()
        self.isLoading = true
        self.searchButtonText = "Searching..."
        var delay = 0.5
        DispatchQueue.global().async {
            let searchResult = self.processor.runSearch()
            let areResults = self.processSearchResults(searchResult)
            if areResults {
                delay = 3.0
            }
        }
        self.resetSearchText(delay: delay)
    }
    
    func resetSearchText(delay: Double) {
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + delay, execute: {
            self.searchButtonText = "Search"
        })
    }
}


struct BackgroundView: NSViewRepresentable {
    
    func makeNSView(context: Context) -> NSView {
        let parent = NSView()
        parent.wantsLayer = true
        parent.layer?.backgroundColor = NSColor(named: NSColor.Name("backgroundColor"))?.cgColor
        parent.layer?.cornerRadius = 20
        parent.layer?.masksToBounds = true
        return parent
    }
      
    func updateNSView(_ view: NSView, context: Context) {
        view.layer?.backgroundColor = NSColor(named: NSColor.Name("backgroundColor"))?.cgColor
    }
    
}

struct DateView: View {
    @Binding var date: String
    private let bgColor = Color("dateViewBackgroundColor")
    private let shadowColor = Color("shadowColor")
    private let backgroundColor = Color("searchButtonColor")
    private let textColor = Color("searchButtonTextColor")
    var body: some View {
        GeometryReader{geometry in
            ZStack(alignment: .center) {
                Rectangle()
                    .foregroundColor(self.backgroundColor)
                    .cornerRadius(10)
                Text(self.date)
                    .foregroundColor(self.textColor)
                    .baselineOffset(-14)
                    .animation(nil)
            }
            .frame(width: geometry.size.width*0.80, height: 40)
            .shadow(color: self.shadowColor, radius: 5, x: 0, y: 0)
            .position(x: geometry.size.width/2, y: self.date != "" ? 60 : 20)
            .animation(.spring(response: 0.25, dampingFraction: 0.75, blendDuration: 2))
        }
    }
}

struct CustomButtonStyle: ButtonStyle {
    private let backgroundColor = Color("searchButtonColor")
    private let pressedColor = Color.init(.sRGB, red: 104/255, green: 219/255, blue: 184/255, opacity: 1)
    private let textColor = Color("searchButtonTextColor")
    private let shadowColor = Color("shadowColor")
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .white : textColor)
            .background(configuration.isPressed ? pressedColor : backgroundColor)
            .cornerRadius(10)
    }
        
}

struct ProgressBar: View {
    @Binding var value: Float
    @Binding var animate: Bool
    private let shadowColor = Color(NSColor(named: NSColor.Name("shadowColor"))!)

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .foregroundColor(Color("progressBarBackgroundColor"))
                    
                Rectangle()
                    .frame(width: min(CGFloat(self.value)*geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(Color("progressBarForegroundColor"))
                    .animation(self.animate ? .easeIn : .none)
            }
                .cornerRadius(12)
                
                
        }
        .shadow(color: self.shadowColor, radius: 5, x: 0, y: 0)
    }
    
    
}

struct LoadingCirle: View {
    @Binding var isRotating : Bool
    var body: some View {
        GeometryReader {geometry in
            ZStack(alignment: .center) {
                Circle()
                    .trim(from: 0.0, to: 0.33)
                    .stroke(lineWidth: 3.0)
                    .foregroundColor(Color.white)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .rotationEffect(self.isRotating ? Angle(degrees: 360) : Angle(degrees: 0))
                    .animation(self.isRotating ? Animation.linear(duration: 1)
                        .repeatForever(autoreverses: false) : .default)
  
                Circle()
                    .trim(from: 0.33, to: 0.66)
                    .stroke(lineWidth: 3.0)
                    .foregroundColor(Color.white)
                    .frame(width: geometry.size.width-3, height: geometry.size.height-3)
                    .rotationEffect(self.isRotating ? Angle(degrees: 0) : Angle(degrees: 360))
                    .animation(self.isRotating ? Animation.linear(duration: 0.5)
                        .repeatForever(autoreverses: false) : .default)
            }
            
        }.padding(.all, 10)
    }
}

struct FitToContainer: ViewModifier {
    var fraction: CGFloat = 1.0
    func body(content: Content) -> some View {
        GeometryReader { g in
        content
            .font(.system(size: g.size.height*self.fraction))
            .minimumScaleFactor(0.01)
            .lineLimit(1)
            .frame(width: g.size.width*self.fraction)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(Processor())
//            .environmentObject(MenuBarAnimation(statusBarItem: statusItem, imageNamePattern: "frame-", imageCount: 30))
    }
}
