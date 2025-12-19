//
//  ProjectFolder.swift
//  BookMarks
//
//  Created by Michael Martell on 12/18/25.
//

import Foundation
import SwiftData

@Model
final class ProjectFolder {
    var id: UUID
    var name: String
    var folderPath: String
    var bookmarkData: Data?
    var createdAt: Date
    
    init(name: String, folderPath: String, bookmarkData: Data? = nil) {
        self.id = UUID()
        self.name = name
        self.folderPath = folderPath
        self.bookmarkData = bookmarkData
        self.createdAt = Date()
    }
}

