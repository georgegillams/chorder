//
//  Chord.swift
//  SoftwareChordingKeyboard
//
//  Created by George Gillams on 05/04/2023.
//

import Foundation

let SPECIAL_CHARS = "*&^%$£@!#~`()[]{}<>?/;:.,-_=+)1234567890"

let maximumOutputChunkLength = 10

class Chord: Identifiable {
    @Published var input: String
    var inputSorted: String
    var deleteCount: Int
    @Published var output: String
    var outputChunks: [String] = []
    var pipeNegativePosition: Int
    var hasPipe: Bool

    // TODO: To be set when stats are loaded from file
    var usageCount: Int?{
        didSet {
            if(usageCount == nil)
            {
                usageCountPretty = "-"
            }
            usageCountPretty = String(usageCount ?? 0)
        }
    }
    @Published var usageCountPretty: String = "-"

    init(input: String, output: String) {
        // NOTE: input and output strings should be unmodified, as these will be saved to settings file and re-read when the app is started.
        self.input = input
        self.output = output
        self.deleteCount = 0
        self.pipeNegativePosition = 0
        self.hasPipe = false
        self.inputSorted = String(input.sorted())

        // replace escaped pipes with a placeholder
        let escapedPipePlaceholder = findSpecialCharNotInString(str: output)
        let escapedOutput = output.replacingOccurrences(of: "\\|", with: escapedPipePlaceholder)

        // check that there is only one un-escaped pipe
        if(escapedOutput.components(separatedBy: "|").count > 2) {
            gDebugPrint("Error: Chord output has more than one pipe")
            return
        }

        // find unescaped pipe position in output string
        let pipeIndex = escapedOutput.firstIndex(of: "|") ?? escapedOutput.endIndex
        let pipePosition = escapedOutput.distance(from: escapedOutput.startIndex, to: pipeIndex)

        // remove pipes from output string
        let outputWithoutPipes = escapedOutput.replacingOccurrences(of: "|", with: "")

        // return pipe placeholders
        let outputWithPipes = outputWithoutPipes.replacingOccurrences(of: escapedPipePlaceholder, with: "|")

        self.deleteCount = input.count
        self.outputChunks = outputWithPipes.chunked(into: maximumOutputChunkLength)
        self.pipeNegativePosition = escapedOutput.count - pipePosition
        self.hasPipe = escapedOutput.contains("|")

        if(self.pipeNegativePosition > 0) {
            // subtract one from the pipe position, as the pipe won't be output so we don't need to go back an extra time for the pipe.
            self.pipeNegativePosition -= 1
        }
    }

    func findSpecialCharNotInString (str: String) -> String {
        for char in SPECIAL_CHARS {
            if(!str.contains(String(char))) {
                return String(char)
            }
        }
        return "*"
    }

    func incrementUsageCount() {
        if(usageCount == nil) {
            usageCount = 0
        }

        usageCount! += 1
    }
}

extension String {
    func chunked(into size: Int) -> [String] {
        stride(from: 0, to: count, by: size).map {
            String(self[index(startIndex, offsetBy: $0)..<index(startIndex, offsetBy: min($0 + size, count))])
        }
    }
}
