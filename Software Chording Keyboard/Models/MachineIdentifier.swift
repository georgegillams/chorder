//
//  MachineIdentifier.swift
//  Software Chording Keyboard
//
//  Created by George Gillams on 05/06/2026.
//

import Foundation
import IOKit

enum MachineIdentifier {
    private static let userDefaultsKey = "machineIdentifier"

    static var current: String {
        if let platformUUID = ioPlatformUUID() {
            return platformUUID
        }
        return persistedUUID()
    }

    private static func ioPlatformUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        guard service != 0 else {
            return nil
        }
        guard let uuid = IORegistryEntryCreateCFProperty(
            service,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String, !uuid.isEmpty else {
            return nil
        }
        return uuid
    }

    private static func persistedUUID() -> String {
        if let existing = UserDefaults.standard.string(forKey: userDefaultsKey), !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: userDefaultsKey)
        return newId
    }
}
