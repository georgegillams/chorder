//
//  AppModel.swift
//  Software Chording Keyboard
//
//  Created by George Gillams on 06/04/2023.
//

import Combine
import Foundation

class AppModel: ObservableObject {
    var appSettings = AppSettings()
    private var cancellables = Set<AnyCancellable>()

    init() {
        appSettings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
