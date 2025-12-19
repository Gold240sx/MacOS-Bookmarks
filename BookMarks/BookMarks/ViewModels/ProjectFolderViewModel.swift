//
//  ProjectFolderViewModel.swift
//  BookMarks
//
//  Created by Michael Martell on 12/18/25.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ProjectFolderViewModel {
    private var modelContext: ModelContext?
    private let bookmarkManager = BookmarkManager.shared
    private let markerManager = FolderMarkerManager.shared
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    /// Adds a new project folder
    func addProjectFolder(name: String, url: URL) throws {
        guard let context = modelContext else {
            throw ViewModelError.noModelContext
        }
        
        // Create bookmark for the folder
        print("Creating bookmark for: \(url.path)")
        let bookmarkData = try bookmarkManager.createBookmark(for: url)
        print("Bookmark created successfully, size: \(bookmarkData.count) bytes")
        
        let projectFolder = ProjectFolder(
            name: name,
            folderPath: url.path,
            bookmarkData: bookmarkData
        )
        
        context.insert(projectFolder)
        try context.save()
        print("Project folder saved with bookmark data")
        
        // Create marker file in the folder for Finder searchability
        // With full disk access (no sandbox), we can write directly
        // Use the stored path directly (not the bookmark-resolved URL) to avoid security-scoped access issues
        do {
            let folderURL = URL(fileURLWithPath: url.path)
            try markerManager.createMarkerFile(
                in: folderURL,
                projectName: name,
                projectID: projectFolder.id
            )
        } catch {
            print("Error creating marker file: \(error.localizedDescription)")
            print("Full error: \(error)")
            // Don't fail the entire operation if marker file creation fails
            // The bookmark will still work for tracking the folder
        }
    }
    
    /// Sync status information
    struct SyncStatus {
        let isSynced: Bool
        let storedPath: String
        let actualPath: String?
        let wasResolved: Bool
        let isInTrash: Bool
    }
    
    /// Checks the sync status of a project folder without updating it
    /// This properly compares stored path with bookmark-resolved path
    /// Also searches for marker files if the stored path doesn't exist
    /// Returns a tuple with sync status and whether a search is needed
    func checkSyncStatus(_ projectFolder: ProjectFolder) -> (status: SyncStatus, needsSearch: Bool) {
        let storedPath = projectFolder.folderPath
        var actualPathFromBookmark: String? = nil
        var bookmarkResolved = false
        
        // Always try to resolve via bookmark first to get the actual location
        if let bookmarkData = projectFolder.bookmarkData {
            do {
                let resolvedURL = try bookmarkManager.resolveBookmark(bookmarkData)
                defer {
                    bookmarkManager.stopAccessing(resolvedURL)
                }
                
                if bookmarkManager.folderExists(at: resolvedURL) {
                    actualPathFromBookmark = resolvedURL.path
                    bookmarkResolved = true
                }
            } catch {
                print("Failed to resolve bookmark for sync check: \(error)")
            }
        }
        
        // Check if stored path exists
        let storedPathExists = bookmarkManager.folderExists(at: storedPath)
        
        // Check if stored path is in trash
        let storedPathInTrash = bookmarkManager.isInTrash(path: storedPath)
        
        // Check if resolved path is in trash
        var actualPathInTrash = false
        if let actualPathFromBookmark = actualPathFromBookmark {
            actualPathInTrash = bookmarkManager.isInTrash(path: actualPathFromBookmark)
        }
        
        // Determine if we need to search (stored path doesn't exist and bookmark didn't resolve)
        let needsSearch = !storedPathExists && actualPathFromBookmark == nil && !storedPathInTrash
        
        // Determine actual path (prefer bookmark, then stored)
        let actualPath = actualPathFromBookmark ?? (storedPathExists ? storedPath : nil)
        let wasResolved = bookmarkResolved
        let isInTrash = storedPathInTrash || actualPathInTrash
        
        // Determine sync status
        if let actualPath = actualPath {
            let pathsMatch = actualPath == storedPath
            let isSynced = storedPathExists && pathsMatch && !isInTrash
            
            if !isSynced && !storedPathExists {
                // Stored path doesn't exist but we found it via bookmark - folder was moved
                print("Sync check: Folder moved from \(storedPath) to \(actualPath) (found via bookmark)")
            } else if !isSynced && storedPathExists {
                // Both exist but different - this shouldn't happen, but handle it
                print("Sync check: Paths differ - stored: \(storedPath), actual: \(actualPath)")
            }
            
            if isInTrash {
                print("Warning: Folder is in Trash: \(isInTrash ? actualPath : storedPath)")
            }
            
            return (
                status: SyncStatus(
                    isSynced: isSynced,
                    storedPath: storedPath,
                    actualPath: actualPath,
                    wasResolved: wasResolved,
                    isInTrash: isInTrash
                ),
                needsSearch: false
            )
        } else if storedPathExists {
            // Only stored path exists (no bookmark found)
            return (
                status: SyncStatus(
                    isSynced: !storedPathInTrash,
                    storedPath: storedPath,
                    actualPath: storedPath,
                    wasResolved: false,
                    isInTrash: storedPathInTrash
                ),
                needsSearch: false
            )
        } else {
            // Neither exists - needs search (unless in trash)
            return (
                status: SyncStatus(
                    isSynced: false,
                    storedPath: storedPath,
                    actualPath: nil,
                    wasResolved: false,
                    isInTrash: storedPathInTrash
                ),
                needsSearch: needsSearch
            )
        }
    }
    
    /// Searches for a folder by marker file asynchronously
    nonisolated func searchForFolderByMarker(projectFolder: ProjectFolder) async -> URL? {
        let projectID = projectFolder.id
        let markerManager = FolderMarkerManager.shared
        
        return await Task.detached {
            return markerManager.findFolderByMarker(projectID: projectID)
        }.value
    }
    
    /// Restores a folder from trash to its previous location
    /// Uses the bookmark or marker file search to determine where it was before being moved to trash
    func restoreFolderFromTrash(projectFolder: ProjectFolder) -> (success: Bool, message: String) {
        guard let context = modelContext else {
            return (false, "No model context available")
        }
        
        // First, resolve the bookmark to get the actual trash location
        // The stored path is the original path, but the bookmark points to the trash location
        var trashURL: URL? = nil
        if let bookmarkData = projectFolder.bookmarkData {
            do {
                let resolvedURL = try bookmarkManager.resolveBookmark(bookmarkData)
                defer {
                    bookmarkManager.stopAccessing(resolvedURL)
                }
                
                // If the resolved URL is in trash, use it
                if bookmarkManager.isInTrash(url: resolvedURL) {
                    trashURL = resolvedURL
                }
            } catch {
                print("Failed to resolve bookmark for trash location: \(error)")
            }
        }
        
        // Fallback to stored path if bookmark didn't resolve to trash
        if trashURL == nil {
            trashURL = URL(fileURLWithPath: projectFolder.folderPath)
        }
        
        guard let trashURL = trashURL else {
            return (false, "Could not determine trash location.")
        }
        
        // Check if folder still exists in trash
        guard bookmarkManager.folderExists(at: trashURL) else {
            return (false, "Folder no longer exists in Trash at: \(trashURL.path)")
        }
        
        // Try to find the previous location using multiple methods
        // The stored path (projectFolder.folderPath) contains the ORIGINAL location before it was moved to trash
        var previousLocation: URL? = nil
        
        // Method 1: Use the stored path to get the parent directory (where it was before trash)
        let storedPath = projectFolder.folderPath
        let storedURL = URL(fileURLWithPath: storedPath)
        let parentOfOriginal = storedURL.deletingLastPathComponent()
        
        // Check if the parent directory exists and is not in trash
        if bookmarkManager.folderExists(at: parentOfOriginal) && !bookmarkManager.isInTrash(url: parentOfOriginal) {
            previousLocation = parentOfOriginal
        }
        
        // Method 2: Try to find the folder by marker file search (might find it elsewhere)
        if previousLocation == nil {
            if let foundURL = markerManager.findFolderByMarker(projectID: projectFolder.id) {
                if !bookmarkManager.isInTrash(url: foundURL) {
                    previousLocation = foundURL
                }
            }
        }
        
        // Method 3: Try to determine from stored path (get parent directory before trash)
        if previousLocation == nil {
            // Extract the folder name from the trash path
            let folderName = trashURL.lastPathComponent
            
            // Try common locations
            let fileManager = FileManager.default
            let commonLocations = [
                fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first,
                fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
                fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
                fileManager.homeDirectoryForCurrentUser
            ].compactMap { $0 }
            
            // Check if folder exists in any common location (maybe it was duplicated)
            for location in commonLocations {
                let testPath = location.appendingPathComponent(folderName)
                if bookmarkManager.folderExists(at: testPath) {
                    // Found a folder with the same name - use its parent
                    previousLocation = location
                    break
                }
            }
            
            // If still not found, default to Desktop
            if previousLocation == nil {
                previousLocation = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
            }
        }
        
        guard let restoreLocation = previousLocation else {
            return (false, "Could not determine previous folder location. Please use 'Select New Location' to manually restore.")
        }
        
        // Move the folder from trash to previous location
        let fileManager = FileManager.default
        let folderName = trashURL.lastPathComponent
        
        // If restoreLocation is the folder itself (from bookmark), use its parent
        let destinationURL: URL
        if restoreLocation.lastPathComponent == folderName {
            // The resolved location IS the folder, so restore to its parent
            destinationURL = restoreLocation.deletingLastPathComponent().appendingPathComponent(folderName)
        } else {
            // Restore to the determined location
            destinationURL = restoreLocation.appendingPathComponent(folderName)
        }
        
        // Check if destination already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            return (false, "A folder with this name already exists at the destination:\n\(destinationURL.path)\n\nPlease remove it first or choose a different location.")
        }
        
        do {
            // Move the folder
            try fileManager.moveItem(at: trashURL, to: destinationURL)
            print("Moved folder from trash to: \(destinationURL.path)")
            
            // Update the folder path
            projectFolder.folderPath = destinationURL.path
            
            // Update bookmark for new location
            let resource = SecurityScopedResource(url: destinationURL)
            resource.withAccess { url in
                if let newBookmarkData = try? bookmarkManager.createBookmark(for: url) {
                    projectFolder.bookmarkData = newBookmarkData
                }
            }
            
            // Update marker file in new location
            do {
                try markerManager.updateMarkerFile(
                    in: destinationURL,
                    projectName: projectFolder.name,
                    projectID: projectFolder.id
                )
            } catch {
                print("Warning: Failed to update marker file: \(error)")
            }
            
            // Save changes
            try context.save()
            
            return (true, "Folder restored to:\n\(destinationURL.path)")
        } catch {
            return (false, "Failed to move folder:\n\(error.localizedDescription)")
        }
    }
    
    /// Manually updates the folder path when user selects a new location
    func updateFolderPathManually(projectFolder: ProjectFolder, newURL: URL) -> Bool {
        guard let context = modelContext else {
            return false
        }
        
        let newPath = newURL.path
        
        // Update the folder path
        projectFolder.folderPath = newPath
        
        // Create new bookmark for the new location
        let resource = SecurityScopedResource(url: newURL)
        resource.withAccess { url in
            if let newBookmarkData = try? bookmarkManager.createBookmark(for: url) {
                projectFolder.bookmarkData = newBookmarkData
            }
        }
        
        // Update marker file in new location
        do {
            try markerManager.updateMarkerFile(
                in: newURL,
                projectName: projectFolder.name,
                projectID: projectFolder.id
            )
        } catch {
            print("Warning: Failed to update marker file: \(error)")
        }
        
        // Save changes
        do {
            try context.save()
            print("Manually updated folder path to: \(newPath)")
            return true
        } catch {
            print("Error saving manual path update: \(error)")
            return false
        }
    }
    
    /// Resolves a project folder and updates it if the path changed
    /// Properly handles security-scoped resource access
    /// Also searches for marker files if bookmark resolution fails
    /// Returns the resolved URL and sync status - caller should manage security-scoped access if needed
    func resolveAndUpdate(_ projectFolder: ProjectFolder, showPrompt: Bool = true) -> (url: URL?, syncStatus: SyncStatus) {
        // First try bookmark resolution
        var resolvedURL = bookmarkManager.resolveProjectFolder(
            folderPath: projectFolder.folderPath,
            bookmarkData: projectFolder.bookmarkData,
            showPrompt: false, // Don't prompt yet, try marker search first
            onUserPrompt: { nil }
        )
        
        // If bookmark resolution failed, try marker file search
        if resolvedURL == nil {
            print("Bookmark resolution failed, searching for marker file...")
            if let markerFolderURL = markerManager.findFolderByMarker(projectID: projectFolder.id) {
                resolvedURL = markerFolderURL
                print("Found folder via marker search: \(markerFolderURL.path)")
            }
        }
        
        // If still not found and showPrompt is true, ask user
        if resolvedURL == nil && showPrompt {
            resolvedURL = bookmarkManager.promptForFolder(
                title: "Locate '\(projectFolder.name)' folder"
            )
        }
        
        guard let resolvedURL = resolvedURL,
              let context = modelContext else {
            let syncStatus = SyncStatus(
                isSynced: false,
                storedPath: projectFolder.folderPath,
                actualPath: nil,
                wasResolved: false,
                isInTrash: bookmarkManager.isInTrash(path: projectFolder.folderPath)
            )
            return (nil, syncStatus)
        }
        
        let actualPath = resolvedURL.path
        let storedPath = projectFolder.folderPath
        let wasOutOfSync = actualPath != storedPath
        
        // Check if the resolved location is in trash BEFORE updating SwiftData
        // This prevents overwriting the original path, allowing restore to work
        let isInTrash = bookmarkManager.isInTrash(url: resolvedURL)
        if isInTrash {
            print("Folder is in trash at: \(actualPath) - NOT updating SwiftData to preserve original path")
            let syncStatus = SyncStatus(
                isSynced: false,
                storedPath: storedPath,
                actualPath: actualPath,
                wasResolved: true,
                isInTrash: true
            )
            return (resolvedURL, syncStatus)
        }
        
        // Update the folder path and bookmark if it changed (and not in trash)
        if wasOutOfSync {
            print("Folder moved from \(storedPath) to \(actualPath) - updating...")
            
            // Update the stored path first
            projectFolder.folderPath = actualPath
            
            // Update bookmark with new location (need access for bookmark creation)
            let resource = SecurityScopedResource(url: resolvedURL)
            resource.withAccess { url in
                do {
                    let newBookmarkData = try bookmarkManager.createBookmark(for: url)
                    projectFolder.bookmarkData = newBookmarkData
                    print("Bookmark updated for new location")
                } catch {
                    print("Warning: Failed to update bookmark: \(error)")
                }
            }
            
            // Update marker file in new location (use direct path, no security-scoped access needed)
            let folderURL = URL(fileURLWithPath: actualPath)
            do {
                try markerManager.updateMarkerFile(
                    in: folderURL,
                    projectName: projectFolder.name,
                    projectID: projectFolder.id
                )
                print("Marker file updated at new location")
            } catch {
                print("Warning: Failed to update marker file: \(error)")
            }
            
            // Save the changes
            do {
                try context.save()
                print("SwiftData updated with new path: \(actualPath)")
            } catch {
                print("Error saving updated path: \(error)")
            }
        }
        
        // After potential update, check if it's now synced
        let finalStoredPath = projectFolder.folderPath
        let isSynced = actualPath == finalStoredPath
        
        let syncStatus = SyncStatus(
            isSynced: isSynced,
            storedPath: finalStoredPath,
            actualPath: actualPath,
            wasResolved: wasOutOfSync,
            isInTrash: false // Already checked above, not in trash if we got here
        )
        
        // Return the URL - if it came from a bookmark, security-scoped access is already started
        // The caller can use SecurityScopedResource to manage it properly if needed
        return (resolvedURL, syncStatus)
    }
    
    /// Gets a security-scoped resource for a project folder
    func getSecurityScopedResource(for projectFolder: ProjectFolder) -> SecurityScopedResource? {
        guard let url = bookmarkManager.resolveProjectFolder(
            folderPath: projectFolder.folderPath,
            bookmarkData: projectFolder.bookmarkData,
            showPrompt: false,
            onUserPrompt: { nil }
        ) else {
            return nil
        }
        
        return SecurityScopedResource(url: url)
    }
    
    /// Tests if the bookmark for a project folder is valid
    func testBookmark(for projectFolder: ProjectFolder) -> (success: Bool, message: String) {
        guard let bookmarkData = projectFolder.bookmarkData, !bookmarkData.isEmpty else {
            return (false, "No bookmark data stored")
        }
        
        do {
            let url = try bookmarkManager.resolveBookmark(bookmarkData)
            defer {
                bookmarkManager.stopAccessing(url)
            }
            
            let exists = bookmarkManager.folderExists(at: url)
            if exists {
                let markerExists = markerManager.markerFileExists(in: url, projectName: projectFolder.name)
                let markerStatus = markerExists ? "Marker file exists" : "Marker file missing"
                return (true, "Bookmark is valid - folder found at: \(url.path)\n\(markerStatus)")
            } else {
                return (false, "Bookmark resolved but folder doesn't exist at: \(url.path)")
            }
        } catch {
            return (false, "Failed to resolve bookmark: \(error.localizedDescription)")
        }
    }
    
    /// Ensures marker file exists for a project folder
    func ensureMarkerFile(for projectFolder: ProjectFolder) {
        // Use direct path instead of resolving bookmark to avoid security-scoped access issues
        let folderURL = URL(fileURLWithPath: projectFolder.folderPath)
        
        if !markerManager.markerFileExists(in: folderURL, projectName: projectFolder.name) {
            do {
                try markerManager.createMarkerFile(
                    in: folderURL,
                    projectName: projectFolder.name,
                    projectID: projectFolder.id
                )
            } catch {
                print("Failed to create marker file: \(error)")
            }
        }
    }
    
    /// Deletes a project folder
    func deleteProjectFolder(_ projectFolder: ProjectFolder) throws {
        guard let context = modelContext else {
            throw ViewModelError.noModelContext
        }
        
        // Try to remove marker file if folder is accessible
        if let url = bookmarkManager.resolveProjectFolder(
            folderPath: projectFolder.folderPath,
            bookmarkData: projectFolder.bookmarkData,
            showPrompt: false,
            onUserPrompt: { nil }
        ) {
            let resource = SecurityScopedResource(url: url)
            resource.withAccess { folderURL in
                markerManager.removeMarkerFile(from: folderURL, projectName: projectFolder.name)
            }
            bookmarkManager.stopAccessing(url)
        }
        
        context.delete(projectFolder)
        try context.save()
    }
}

enum ViewModelError: Error {
    case noModelContext
}

