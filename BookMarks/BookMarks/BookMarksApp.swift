//
//  BookMarksApp.swift
//  BookMarks
//
//  Created by Michael Martell on 12/18/25.
//

import SwiftUI
import SwiftData

@main
struct BookMarksApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: ProjectFolder.self)
    }
}
