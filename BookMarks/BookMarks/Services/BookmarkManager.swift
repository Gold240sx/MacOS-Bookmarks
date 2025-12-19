//
//  BookmarkManager.swift
//  BookMarks
//
//  Created by Michael Martell on 12/18/25.
//

import Foundation
import AppKit

class BookmarkManager {
    static let shared = BookmarkManager()
    
    private init() {}
    
    /// Creates a security-scoped bookmark from a folder URL
    /// This allows the app to access the folder even after it's moved or the app restarts
    /// 
    /// Note: macOS bookmarks are NOT files - they're data stored in the app's database.
    /// This bookmark data is stored in SwiftData, not as a file in the folder.
    func createBookmark(for url: URL) throws -> Data {
        // Request access to the security-scoped resource first
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        print("Creating bookmark for URL: \(url.path)")
        print("Accessing security-scoped resource: \(accessing)")
        
        // Create security-scoped bookmark with read-write access
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: [.pathKey, .isDirectoryKey],
                relativeTo: nil
            )
            print("Bookmark created successfully: \(bookmarkData.count) bytes")
            return bookmarkData
        } catch {
            print("Error creating bookmark: \(error)")
            throw error
        }
    }
    
    /// Resolves a bookmark to a URL with proper security-scoped access
    func resolveBookmark(_ bookmarkData: Data) throws -> URL {
        print("Resolving bookmark, size: \(bookmarkData.count) bytes")
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        
        if isStale {
            print("Warning: Bookmark is stale - folder may have been moved")
            // Don't throw immediately - try to resolve anyway, it might still work
            // The caller can handle stale bookmarks by searching for marker files
        }
        
        print("Bookmark resolved to: \(url.path)")
        
        // Start accessing the security-scoped resource
        let accessing = url.startAccessingSecurityScopedResource()
        print("Security-scoped access started: \(accessing)")
        
        return url
    }
    
    /// Stops accessing a security-scoped resource
    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
    
    /// Checks if a folder exists at the given path
    /// Starts security-scoped access if the URL is from a bookmark
    func folderExists(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    /// Checks if a folder exists at the given URL
    /// Properly handles security-scoped resources
    func folderExists(at url: URL) -> Bool {
        // Start accessing security-scoped resource if needed
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    /// Resolves a project folder using the fallback logic:
    /// 1. Try folderPath
    /// 2. Try bookmark
    /// 3. Ask user to specify (if showPrompt is true)
    /// 
    /// Note: The returned URL may have security-scoped access started.
    /// The caller should use SecurityScopedResource to manage access properly.
    func resolveProjectFolder(
        folderPath: String,
        bookmarkData: Data?,
        showPrompt: Bool = true,
        onUserPrompt: @escaping () -> URL?
    ) -> URL? {
        // Step 1: Try the stored folder path
        if folderExists(at: folderPath) {
            let url = URL(fileURLWithPath: folderPath)
            // For regular paths (not from bookmarks), startAccessing returns false
            // which is fine - we don't need security-scoped access for regular paths
            return url
        }
        
        // Step 2: Try to resolve the bookmark
        if let bookmarkData = bookmarkData {
            do {
                let url = try resolveBookmark(bookmarkData)
                // Check if folder exists (this will handle security-scoped access temporarily)
                if folderExists(at: url) {
                    // The URL already has security-scoped access started from resolveBookmark
                    return url
                } else {
                    // Folder doesn't exist, stop accessing
                    stopAccessing(url)
                }
            } catch {
                print("Failed to resolve bookmark: \(error)")
            }
        }
        
        // Step 3: Ask user to specify location (only if showPrompt is true)
        if showPrompt {
            if let userSelectedURL = onUserPrompt() {
                // The promptForFolder already starts security-scoped access
                return userSelectedURL
            }
        }
        
        return nil
    }
    
    /// Prompts user to select a folder
    /// Returns a URL with security-scoped access already started
    func promptForFolder(title: String = "Select Folder") -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        
        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            // Start accessing security-scoped resource for the selected folder
            _ = url.startAccessingSecurityScopedResource()
            return url
        }
        
        return nil
    }
    
    /// Checks if a path is in the Trash folder
    func isInTrash(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return isInTrash(url: url)
    }
    
    /// Checks if a URL is in the Trash folder
    func isInTrash(url: URL) -> Bool {
        // Get the Trash folder URL
        guard let trashURL = try? FileManager.default.url(
            for: .trashDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return false
        }
        
        // Check if the URL is within the Trash directory
        let trashPath = trashURL.path
        let urlPath = url.path
        
        // Check if the path starts with the trash path
        return urlPath.hasPrefix(trashPath)
    }
}

enum BookmarkError: Error {
    case staleBookmark
    case invalidBookmark
    case folderNotFound
}

