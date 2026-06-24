//
//  AppModel.swift
//  Chorder
//
//  Created by George Gillams on 06/04/2023.
//

import Combine
import Foundation

class AppModel: ObservableObject {
    let appSettings = AppSettings()

    // Holds active Combine subscriptions; cancelled automatically when AppModel is deallocated.
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Forward AppSettings changes so SwiftUI views observing AppModel also refresh.
        appSettings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
