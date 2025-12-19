//
//  SecurityScopedResource.swift
//  BookMarks
//
//  Created by Michael Martell on 12/18/25.
//

import Foundation

/// A helper class to manage security-scoped resource access
/// Ensures resources are properly released when done
class SecurityScopedResource {
    private let url: URL
    private var isAccessing: Bool = false
    
    init(url: URL) {
        self.url = url
    }
    
    /// Starts accessing the security-scoped resource
    @discardableResult
    func startAccessing() -> Bool {
        guard !isAccessing else { return true }
        isAccessing = url.startAccessingSecurityScopedResource()
        return isAccessing
    }
    
    /// Stops accessing the security-scoped resource
    func stopAccessing() {
        guard isAccessing else { return }
        url.stopAccessingSecurityScopedResource()
        isAccessing = false
    }
    
    /// Executes a block with security-scoped access, automatically cleaning up
    func withAccess<T>(_ block: (URL) throws -> T) rethrows -> T {
        let wasAccessing = isAccessing
        if !wasAccessing {
            startAccessing()
        }
        defer {
            if !wasAccessing {
                stopAccessing()
            }
        }
        return try block(url)
    }
    
    deinit {
        if isAccessing {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

