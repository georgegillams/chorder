//
//  ContentView.swift
//  SoftwareChordingKeyboard
//
//  Created by George Gillams on 03/04/2023.
//

import SwiftUI

struct ContentView: View {
    @State private var text = ""

    var body: some View {
        VStack {
//            Image(systemName: "globe")
//                .imageScale(.large)
//                .foregroundColor(.accentColor)
            Text("Software Chording Keyboard").font(Font.system(size:24))
            Text("Chord hold duration")
            TextField("", text: .constant("30")).textFieldStyle(RoundedBorderTextFieldStyle())
            
            TextField("Test your chords here…", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
