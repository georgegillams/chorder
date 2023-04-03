//
//  Chord.swift
//  SoftwareChordingKeyboard
//
//  Created by George Gillams on 05/04/2023.
//

import Foundation

let SPECIAL_CHARS = "*&^%$£@!#~`()[]{}<>?/;:.,-_=+)1234567890"

let maximumOutputChunkLength = 10

class Chord {
    
    var input: String
    var deleteCount: Int
    var output: String
    var outputChunks: [String] = []
    var pipeNegativePosition: Int
    
    
    init(input: String, output: String) {
        self.input = input
        self.output = output
        self.deleteCount = 0
        self.pipeNegativePosition = 0
        
        // replace escaped pipes with a placeholder
        let escapedPipePlaceholder = findSpecialCharNotInString(str: output)
        print("escapedPipePlaceholder \(escapedPipePlaceholder)")
        let escapedOutput = output.replacingOccurrences(of: "\\|", with: escapedPipePlaceholder)
        
        // check that there is only one un-escaped pipe
        if(escapedOutput.components(separatedBy: "|").count > 2) {
            print("Error: Chord output has more than one pipe")
            return
        }
        
        // find unewscaped pipe position in output string
        let pipeIdx = escapedOutput.firstIndex(of: "|") ?? escapedOutput.endIndex
        let pipePosition = escapedOutput.distance(from: escapedOutput.startIndex, to: pipeIdx)
        
        // remove pipes from output string
        let outputWithoutPipes = escapedOutput.replacingOccurrences(of: "|", with: "")
        
        // return pipe placeholders
        let outputWithPipes = outputWithoutPipes.replacingOccurrences(of: escapedPipePlaceholder, with: "|")
        
        self.input = input
        self.deleteCount = input.count
        self.output = outputWithPipes
        self.outputChunks = outputWithPipes.chunked(into: maximumOutputChunkLength)
        self.pipeNegativePosition = escapedOutput.count - pipePosition
        
        if(self.pipeNegativePosition > 0) {
            // subtract one from the pipe position, as the pipe won't be output so we don't need to go back an extra time for the pipe.
            self.pipeNegativePosition -= 1
        }
        
        print("input: \(input), output: \(outputWithPipes), pipeNegativePosition: \(pipeNegativePosition)")
    }
    
    func findSpecialCharNotInString (str: String) -> String {
        for char in SPECIAL_CHARS {
            if(!str.contains(String(char))) {
                return String(char)
            }
        }
        return "*"
    }
}

extension String {
    func chunked(into size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map {
            String(self[index(startIndex, offsetBy: $0)..<index(startIndex, offsetBy: min($0 + size, count))])
        }
    }
}
