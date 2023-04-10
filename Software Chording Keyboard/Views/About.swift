//
//  About.swift
//  SpeedyColourContrastChecker
//
//  Created by George Gillams on 02/09/2022.
//

import Cocoa
import SwiftUI

struct AboutView: View {
    var delegate: AppDelegate = NSApp.delegate as! AppDelegate
    var versionNsObject: AnyObject? = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as AnyObject
    
    var body: some View {
        let version = versionNsObject as! String
        VStack {
            VStack(alignment: .center) {
                //                Image("eyedropper-3d")
                //                    .resizable()
                //                    .scaledToFit()
                //                    .frame(width: 64, height: 64)
                
                Text("Speedy Contrast Checker \(version)")
                    .bold()
                    .font(.title)
                    .padding(.vertical, 5.0)
                
                
                Text("Created by George Gillams")
                    .underline()
                    .onTapGesture {
                        if let url = URL(string: "https://www.georgegillams.co.uk/") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                
            }
            .padding(.vertical, 10.0)
            
            Button(action: {
                //                    delegate.showWelcomeTutorial()
            }) {
                Text("View welcome tutorial")
            }
            
            HStack {
                Text("Bug or Feature?")
                
                Button(action: {
                    if let url = URL(string: "https://www.georgegillams.co.uk/contact") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Tell Me")
                }
            }
        }.padding(10.0)
            .background(Color.clear)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .center)
    }
}

class AboutWindowController {
    static func createWindow() {
        var windowRef: NSWindow
        windowRef = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 240),
            styleMask: [
                .titled,
                .closable,
                .borderless],
            backing: .buffered, defer: false)
        windowRef.contentView = NSHostingView(rootView: AboutView())
        windowRef.title = "About Speedy Contrast Checker"
        windowRef.level = .floating
        windowRef.isReleasedWhenClosed = false
        windowRef.makeKeyAndOrderFront(nil)
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView().frame(width: 380, height: 240)
    }
}
