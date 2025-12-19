//
//  PermissionHelper.swift
//  BookMarks
//
//  Created by Michael Martell on 12/18/25.
//

import Foundation
import AppKit

class PermissionHelper {
    static let shared = PermissionHelper()
    
    private init() {}
    
    /// Checks if the app has full disk access
    /// This is a best-effort check - it tries to access a protected location
    func checkFullDiskAccess() -> Bool {
        // Try to access a protected location that requires full disk access
        let protectedPath = "/Library/Application Support"
        let fileManager = FileManager.default
        
        // Check if we can list contents of a protected directory
        do {
            _ = try fileManager.contentsOfDirectory(atPath: protectedPath)
            return true
        } catch {
            // If we get a permission error, we likely don't have full disk access
            return false
        }
    }
    
    /// Opens System Settings to the Full Disk Access section
    func openFullDiskAccessSettings() {
        // Open System Settings to Privacy & Security > Full Disk Access
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback: open System Settings
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)
        }
    }
    
    /// Shows an alert asking user to grant full disk access
    func requestFullDiskAccess() {
        let alert = NSAlert()
        alert.messageText = "Full Disk Access Required"
        alert.informativeText = "BookMarks needs Full Disk Access to create marker files in your project folders.\n\nPlease grant Full Disk Access in System Settings, then restart the app."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openFullDiskAccessSettings()
        }
    }
    
    /// Checks full disk access and prompts if needed
    func ensureFullDiskAccess() -> Bool {
        if !checkFullDiskAccess() {
            requestFullDiskAccess()
            return false
        }
        return true
    }
}

