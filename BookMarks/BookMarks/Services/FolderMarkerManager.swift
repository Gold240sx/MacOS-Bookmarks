//
//  FolderMarkerManager.swift
//  BookMarks
//
//  Created by Michael Martell on 12/18/25.
//

import Foundation
import CoreServices
import AppKit

nonisolated class FolderMarkerManager {
    nonisolated static let shared = FolderMarkerManager()
    static let markerFileExtension = "DSBookmark"
    
    nonisolated private init() {}
    
    /// Gets the marker file name for a project folder
    static func markerFileName(for projectName: String) -> String {
        // Sanitize the project name for use as a filename
        let sanitized = projectName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        return "\(sanitized).\(markerFileExtension)"
    }
    
    /// Creates a marker file in the folder for Finder searchability
    /// The file contains metadata about the project folder
    /// With full disk access (no sandbox), this works without security-scoped access
    func createMarkerFile(in folderURL: URL, projectName: String, projectID: UUID) throws {
        let markerFileName = Self.markerFileName(for: projectName)
        var markerURL = folderURL.appendingPathComponent(markerFileName)
        
        // Create a plist with project information
        let markerData: [String: Any] = [
            "projectName": projectName,
            "projectID": projectID.uuidString,
            "createdBy": "BookMarks",
            "createdAt": Date().iso8601String,
            "version": "1.0"
        ]
        
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: markerData,
            format: .xml,
            options: 0
        )
        
        // Use FileManager to write the file
        // With full disk access (no sandbox), we can write directly
        let fileManager = FileManager.default
        
        // Check folder permissions
        let folderPath = folderURL.path
        guard fileManager.fileExists(atPath: folderPath) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, 
                        userInfo: [NSLocalizedDescriptionKey: "Folder does not exist: \(folderPath)"])
        }
        
        // Check if folder is writable
        guard fileManager.isWritableFile(atPath: folderPath) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError,
                        userInfo: [NSLocalizedDescriptionKey: "Folder is not writable: \(folderPath)"])
        }
        
        // Use FileManager to create the file (more reliable than Data.write)
        let success = fileManager.createFile(
            atPath: markerURL.path,
            contents: plistData,
            attributes: nil
        )
        
        guard success else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create marker file at: \(markerURL.path)"])
        }
        
        // Make it searchable by Spotlight (Finder search)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = false
        try? markerURL.setResourceValues(resourceValues)
        
        // Set custom icon for the file
        setCustomIcon(for: markerURL)
        
        print("Created marker file at: \(markerURL.path)")
    }
    
    /// Sets a custom icon for the marker file
    private func setCustomIcon(for fileURL: URL) {
        // Get the icon from the app bundle using NSImage(named:)
        if let iconImage = NSImage(named: "devspace-icon") {
            NSWorkspace.shared.setIcon(iconImage, forFile: fileURL.path, options: [])
            print("Set custom icon for marker file: \(fileURL.path)")
        } else {
            // Try loading from the imageset directly
            if let iconPath = Bundle.main.path(forResource: "devspace_logo", ofType: "svg", inDirectory: "Assets.xcassets/devspace-icon.imageset"),
               let iconImage = NSImage(contentsOfFile: iconPath) {
                NSWorkspace.shared.setIcon(iconImage, forFile: fileURL.path, options: [])
                print("Set custom icon for marker file from SVG: \(fileURL.path)")
            } else {
                print("Warning: Could not find devspace-icon in assets")
            }
        }
    }
    
    /// Updates the marker file if it exists
    /// With full disk access (no sandbox), this works without security-scoped access
    func updateMarkerFile(in folderURL: URL, projectName: String, projectID: UUID) throws {
        let markerFileName = Self.markerFileName(for: projectName)
        let markerURL = folderURL.appendingPathComponent(markerFileName)
        
        // Check if file exists, if not create it
        if !FileManager.default.fileExists(atPath: markerURL.path) {
            try createMarkerFile(in: folderURL, projectName: projectName, projectID: projectID)
            return
        }
        
        // Update existing file
        let markerData: [String: Any] = [
            "projectName": projectName,
            "projectID": projectID.uuidString,
            "createdBy": "BookMarks",
            "updatedAt": Date().iso8601String,
            "version": "1.0"
        ]
        
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: markerData,
            format: .xml,
            options: 0
        )
        
        // Use FileManager to write the file
        let fileManager = FileManager.default
        let success = fileManager.createFile(
            atPath: markerURL.path,
            contents: plistData,
            attributes: nil
        )
        
        guard success else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteFileExistsError,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to update marker file at: \(markerURL.path)"])
        }
        
        print("Updated marker file at: \(markerURL.path)")
    }
    
    /// Removes the marker file from a folder
    /// With full disk access (no sandbox), this works without security-scoped access
    func removeMarkerFile(from folderURL: URL, projectName: String) {
        let markerFileName = Self.markerFileName(for: projectName)
        let markerURL = folderURL.appendingPathComponent(markerFileName)
        
        try? FileManager.default.removeItem(at: markerURL)
        print("Removed marker file from: \(folderURL.path)")
    }
    
    /// Finds a project folder by searching for its marker file using the projectID
    /// Uses FileManager to recursively search directories (more reliable than Spotlight)
    nonisolated func findFolderByMarker(projectID: UUID) -> URL? {
        let projectIDString = projectID.uuidString
        let markerFileExtension = Self.markerFileExtension
        
        print("Searching for marker file with projectID: \(projectIDString)")
        
        // First try Spotlight/MDQuery (fast if indexed)
        if let foundURL = findFolderByMarkerSpotlight(projectID: projectID, markerFileExtension: markerFileExtension) {
            return foundURL
        }
        
        // Fallback to FileManager recursive search (slower but more reliable)
        print("Spotlight search failed, using FileManager recursive search...")
        return findFolderByMarkerFileManager(projectID: projectID, markerFileExtension: markerFileExtension)
    }
    
    /// Uses Spotlight/MDQuery to search for marker files
    nonisolated private func findFolderByMarkerSpotlight(projectID: UUID, markerFileExtension: String) -> URL? {
        let projectIDString = projectID.uuidString
        
        // Use Spotlight query to find files with the DSBookmark extension
        // Search for files ending with .DSBookmark
        let queryString = "kMDItemFSName ENDSWITH '.\(markerFileExtension)'"
        
        guard let query = MDQueryCreate(kCFAllocatorDefault, queryString as CFString, nil, nil) else {
            return nil
        }
        
        // Limit search to user's home directory for performance
        let homePath = NSHomeDirectory()
        let searchScope = [homePath] as CFArray
        MDQuerySetSearchScope(query, searchScope, 0)
        
        // Execute the query
        let success = MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue))
        guard success else {
            return nil
        }
        
        let resultCount = MDQueryGetResultCount(query)
        guard resultCount > 0 else {
            return nil
        }
        
        print("Found \(resultCount) marker files with extension '\(markerFileExtension)' via Spotlight")
        
        // Check each result to find the one with matching projectID
        for i in 0..<resultCount {
            guard let rawResult = MDQueryGetResultAtIndex(query, i) else { continue }
            let result = unsafeBitCast(rawResult, to: MDItem.self)
            
            // Get the file path
            guard let path = MDItemCopyAttribute(result, kMDItemPath) as? String else { continue }
            
            // Read the marker file to check the projectID
            let markerURL = URL(fileURLWithPath: path)
            if let markerData = try? Data(contentsOf: markerURL),
               let plist = try? PropertyListSerialization.propertyList(from: markerData, options: [], format: nil) as? [String: Any],
               let markerProjectID = plist["projectID"] as? String,
               markerProjectID == projectIDString {
                
                // Found it! Get the parent folder
                let folderURL = markerURL.deletingLastPathComponent()
                print("Found folder by marker (Spotlight): \(folderURL.path)")
                return folderURL
            }
        }
        
        return nil
    }
    
    /// Uses FileManager to recursively search for marker files
    nonisolated private func findFolderByMarkerFileManager(projectID: UUID, markerFileExtension: String) -> URL? {
        let projectIDString = projectID.uuidString
        let fileManager = FileManager.default
        
        // Search in common locations: Desktop, Documents, Downloads, and home directory
        let searchPaths = [
            fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            fileManager.homeDirectoryForCurrentUser
        ].compactMap { $0 }
        
        for searchPath in searchPaths {
            if let foundURL = searchDirectoryRecursively(
                at: searchPath,
                markerFileExtension: markerFileExtension,
                projectID: projectIDString,
                fileManager: fileManager,
                maxDepth: 5 // Limit depth to avoid searching entire drive
            ) {
                print("Found folder by marker (FileManager): \(foundURL.path)")
                return foundURL
            }
        }
        
        print("Marker file with projectID \(projectIDString) not found")
        return nil
    }
    
    /// Recursively searches a directory for marker files
    nonisolated private func searchDirectoryRecursively(
        at url: URL,
        markerFileExtension: String,
        projectID: String,
        fileManager: FileManager,
        maxDepth: Int,
        currentDepth: Int = 0
    ) -> URL? {
        guard currentDepth < maxDepth else { return nil }
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }
        
        for case let fileURL as URL in enumerator {
            // Check if this is a marker file (has the DSBookmark extension)
            if fileURL.pathExtension == markerFileExtension {
                // Read and check the projectID
                if let markerData = try? Data(contentsOf: fileURL),
                   let plist = try? PropertyListSerialization.propertyList(from: markerData, options: [], format: nil) as? [String: Any],
                   let markerProjectID = plist["projectID"] as? String,
                   markerProjectID == projectID {
                    // Found it! Return the parent folder
                    return fileURL.deletingLastPathComponent()
                }
            }
        }
        
        return nil
    }
    
    /// Reads the projectID from a marker file
    nonisolated func readProjectID(from markerURL: URL) -> UUID? {
        guard let markerData = try? Data(contentsOf: markerURL),
              let plist = try? PropertyListSerialization.propertyList(from: markerData, options: [], format: nil) as? [String: Any],
              let projectIDString = plist["projectID"] as? String,
              let projectID = UUID(uuidString: projectIDString) else {
            return nil
        }
        return projectID
    }
    
    /// Checks if a marker file exists in the folder
    /// With full disk access (no sandbox), this works without security-scoped access
    func markerFileExists(in folderURL: URL, projectName: String) -> Bool {
        let markerFileName = Self.markerFileName(for: projectName)
        let markerURL = folderURL.appendingPathComponent(markerFileName)
        return FileManager.default.fileExists(atPath: markerURL.path)
    }
    
    /// Finds marker files in a folder by checking for DSBookmark extension
    func findMarkerFile(in folderURL: URL) -> URL? {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.nameKey], options: []) else {
            return nil
        }
        
        // Look for any file with DSBookmark extension
        return contents.first { $0.pathExtension == Self.markerFileExtension }
    }
}

extension Date {
    nonisolated var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

