//
//  ContentView.swift
//  BookMarks
//
//  Created by Michael Martell on 12/18/25.
//

import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProjectFolder.createdAt, order: .reverse) private var projectFolders: [ProjectFolder]
    @State private var viewModel = ProjectFolderViewModel()
    @State private var showingAddFolder = false
    @State private var folderName = ""
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationSplitView {
            List {
                ForEach(projectFolders) { folder in
                    ProjectFolderRow(
                        folder: folder,
                        viewModel: viewModel
                    )
                }
                .onDelete(perform: deleteFolders)
            }
            .navigationTitle("Project Folders")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddFolder = true
                    } label: {
                        Label("Add Folder", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFolder) {
                AddFolderSheet(
                    folderName: $folderName,
                    onAdd: addFolder,
                    onCancel: {
                        showingAddFolder = false
                        folderName = ""
                    }
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
        } detail: {
            Text("Select a project folder")
                .foregroundStyle(.secondary)
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
    }
    
    private func addFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Project Folder"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            showingAddFolder = false
            return
        }
        
        // Start accessing security-scoped resource for the selected folder
        // This is necessary to create the bookmark
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let name = folderName.isEmpty ? url.lastPathComponent : folderName
        
        do {
            try viewModel.addProjectFolder(name: name, url: url)
            folderName = ""
            showingAddFolder = false
        } catch {
            errorMessage = "Failed to add folder: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func deleteFolders(offsets: IndexSet) {
        for index in offsets {
            let folder = projectFolders[index]
            do {
                try viewModel.deleteProjectFolder(folder)
            } catch {
                errorMessage = "Failed to delete folder: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
    
    private func removeFolderFromTracking(_ folder: ProjectFolder) {
        do {
            try viewModel.deleteProjectFolder(folder)
        } catch {
            errorMessage = "Failed to remove folder from tracking: \(error.localizedDescription)"
            showingError = true
        }
    }
}

struct ProjectFolderRow: View {
    let folder: ProjectFolder
    let viewModel: ProjectFolderViewModel
    @State private var resolvedPath: String?
    @State private var isResolving = false
    @State private var hasBookmark: Bool = false
    @State private var showingBookmarkTest = false
    @State private var bookmarkTestMessage = ""
    @State private var syncStatus: ProjectFolderViewModel.SyncStatus?
    @State private var isOutOfSync = false
    @State private var hasMarkerFile = false
    @State private var isSearching = false
    @State private var searchFailed = false
    @State private var showingManualLocate = false
    @State private var manualLocateFolder: ProjectFolder? // Folder to update when manually locating
    @State private var showingTrashAlert = false
    @State private var trashAlertFolder: ProjectFolder?
    @State private var showingRestoreError = false
    @State private var restoreErrorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)
                Text(folder.name)
                    .font(.headline)
                Spacer()
                
                // Show out-of-sync indicator
                if isOutOfSync {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .help("Folder location is out of sync - stored path doesn't match actual location")
                        Text("Out of Sync")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                // Show trash indicator
                if syncStatus?.isInTrash == true {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .foregroundStyle(.red)
                            .help("Folder is in the Trash")
                        Text("In Trash")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                
                // Show bookmark status - change color if out of sync
                if hasBookmark {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(isOutOfSync ? .orange : .green)
                        .help(isOutOfSync ? "Bookmark exists but folder location is out of sync" : "Bookmark exists - folder can be tracked if moved")
                } else {
                    Image(systemName: "bookmark.slash")
                        .foregroundStyle(.orange)
                        .help("No bookmark - will prompt if folder moves")
                }
                
                if isResolving {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if isSearching {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Searching...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else if searchFailed {
                    Button {
                        showingManualLocate = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                                .font(.caption2)
                            Text("Locate")
                                .font(.caption2)
                        }
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Click to manually locate this folder")
                }
            }
            
            // Show stored path
            VStack(alignment: .leading, spacing: 2) {
                if syncStatus?.isInTrash == true {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(folder.folderPath)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .strikethrough()
                            .lineLimit(1)
                        
                        Text("⚠️ This folder is in the Trash")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                } else if isOutOfSync {
                    HStack {
                        Text("Stored:")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(folder.folderPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .strikethrough()
                            .lineLimit(1)
                    }
                    
                    if let actualPath = syncStatus?.actualPath {
                        HStack {
                            Text("Actual:")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Text(actualPath)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .lineLimit(1)
                        }
                    }
                } else if searchFailed {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(folder.folderPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .strikethrough()
                            .lineLimit(1)
                        
                        Text("Folder not found. Click 'Locate' to find it manually.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                } else {
                    if let resolvedPath = resolvedPath {
                        Text(resolvedPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(folder.folderPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            // Show bookmark and marker file info
            HStack(spacing: 8) {
                if hasBookmark {
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2)
                        Text("\(folder.bookmarkData?.count ?? 0) bytes")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }
                
                if hasMarkerFile {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .font(.caption2)
                        Text("Marker file")
                            .font(.caption2)
                    }
                    .foregroundStyle(.green)
                    .help("Marker file exists - searchable in Finder")
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                        Text("No marker")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange)
                    .help("No marker file - not searchable in Finder")
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            resolveFolder()
        }
        .contextMenu {
            if hasBookmark {
                Button("Test Bookmark") {
                    testBookmark()
                }
            }
            Button("Resolve Folder") {
                resolveFolder()
            }
            if isOutOfSync {
                Button("Update to Current Location") {
                    resolveFolder(showPrompt: false)
                }
            }
            if !hasMarkerFile {
                Button("Create Marker File") {
                    viewModel.ensureMarkerFile(for: folder)
                    checkSyncStatus()
                }
            }
        }
        .alert("Bookmark Test", isPresented: $showingBookmarkTest) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(bookmarkTestMessage)
        }
        .alert("Folder in Trash", isPresented: $showingTrashAlert) {
            if let trashFolder = trashAlertFolder {
                Button("Restore to Prior Folder") {
                    let result = viewModel.restoreFolderFromTrash(projectFolder: trashFolder)
                    if result.success {
                        showingTrashAlert = false
                        trashAlertFolder = nil
                        checkSyncStatus()
                    } else {
                        restoreErrorMessage = result.message
                        showingRestoreError = true
                    }
                }
                Button("Update Location") {
                    manualLocateFolder = trashFolder
                    showingTrashAlert = false
                    showingManualLocate = true
                }
                Button("Remove from Projects", role: .destructive) {
                    do {
                        try viewModel.deleteProjectFolder(trashFolder)
                        showingTrashAlert = false
                        trashAlertFolder = nil
                    } catch {
                        print("Failed to remove folder from tracking: \(error)")
                    }
                }
            } else {
                Button("OK", role: .cancel) {
                    showingTrashAlert = false
                    trashAlertFolder = nil
                }
            }
        } message: {
            if let trashFolder = trashAlertFolder {
                Text("The folder '\(trashFolder.name)' is in the Trash.\n\nWhat would you like to do?")
            } else {
                Text("A tracked folder is in the Trash.")
            }
        }
        .alert("Restore Failed", isPresented: $showingRestoreError) {
            Button("OK", role: .cancel) {
                showingRestoreError = false
            }
        } message: {
            Text(restoreErrorMessage)
        }
        .sheet(isPresented: $showingManualLocate) {
            ManualLocateSheet(
                folderName: (manualLocateFolder ?? folder).name,
                onLocate: { selectedURL in
                    if let url = selectedURL {
                        // Use the folder from manualLocateFolder if set (from trash alert), otherwise use current folder
                        let folderToUpdate = manualLocateFolder ?? folder
                        
                        // Manually update the folder path with the selected URL
                        Task {
                            await MainActor.run {
                                isResolving = true
                            }
                            
                            // Update using the selected URL
                            let result = viewModel.updateFolderPathManually(projectFolder: folderToUpdate, newURL: url)
                            
                            await MainActor.run {
                                if result {
                                    searchFailed = false
                                    isResolving = false
                                    checkSyncStatus()
                                    // If this was from trash alert, trigger sync check for that folder too
                                    if manualLocateFolder != nil {
                                        // The folder path was updated, sync status will be checked automatically
                                    }
                                } else {
                                    isResolving = false
                                }
                            }
                        }
                    }
                    showingManualLocate = false
                    manualLocateFolder = nil
                },
                onCancel: {
                    showingManualLocate = false
                    manualLocateFolder = nil
                }
            )
        }
        .onAppear {
            // Check if bookmark exists
            hasBookmark = folder.bookmarkData != nil && !folder.bookmarkData!.isEmpty
            
            // Check sync status on appear
            checkSyncStatus()
            
            // Ensure marker file exists for existing folders
            viewModel.ensureMarkerFile(for: folder)
        }
        .onChange(of: folder.folderPath) {
            // Re-check sync status when folder path changes
            checkSyncStatus()
        }
        .task {
            // Periodically check sync status to detect moved folders
            // Use longer interval to avoid excessive searching
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // Check every 10 seconds
                checkSyncStatus()
            }
        }
    }
    
    private func checkSyncStatus() {
        let result = viewModel.checkSyncStatus(folder)
        syncStatus = result.status
        let status = result.status
        
        // If in trash, trigger alert and don't auto-update (preserve original path for restore)
        if status.isInTrash {
            trashAlertFolder = folder
            showingTrashAlert = true
            // Don't auto-update when in trash - preserve original path for restore
            isOutOfSync = false // Don't show as out of sync when in trash
            return
        }
        
        // Determine if out of sync: stored path doesn't match actual path
        isOutOfSync = !status.isSynced && status.actualPath != nil && status.actualPath != status.storedPath
        
        // If search is needed, start searching
        if result.needsSearch && !isSearching && !searchFailed {
            Task {
                await searchForFolder()
            }
        }
        
        if let actualPath = status.actualPath {
            resolvedPath = actualPath
            // Check for marker file at actual location
            checkMarkerFile(at: actualPath)
            
            // Auto-update if out of sync (folder was moved) - but not if in trash (checked above)
            if isOutOfSync {
                // Automatically update the path in the background
                Task {
                    await autoUpdatePath()
                }
            }
        } else {
            resolvedPath = folder.folderPath
            // Check for marker file at stored location
            checkMarkerFile(at: folder.folderPath)
        }
    }
    
    private func searchForFolder() async {
        await MainActor.run {
            isSearching = true
            searchFailed = false
        }
        
        // Search for folder by marker file
        if let foundURL = await viewModel.searchForFolderByMarker(projectFolder: folder) {
            await MainActor.run {
                // Found it! Update the path
                let result = viewModel.resolveAndUpdate(folder, showPrompt: false)
                if result.url == nil {
                    // Use the found URL to update
                    _ = viewModel.updateFolderPathManually(projectFolder: folder, newURL: foundURL)
                }
                isSearching = false
                searchFailed = false
                checkSyncStatus()
            }
        } else {
            await MainActor.run {
                isSearching = false
                searchFailed = true
            }
        }
    }
    
    
    private func autoUpdatePath() async {
        // Automatically resolve and update the folder path when out of sync
        await MainActor.run {
            isResolving = true
        }
        
        let result = viewModel.resolveAndUpdate(folder, showPrompt: false)
        
        await MainActor.run {
            syncStatus = result.syncStatus
            // After update, check if it's now synced
            isOutOfSync = !result.syncStatus.isSynced && result.syncStatus.actualPath != nil && result.syncStatus.actualPath != result.syncStatus.storedPath
            
            if let url = result.url {
                resolvedPath = url.path
                checkMarkerFile(at: url.path)
            } else {
                resolvedPath = folder.folderPath
            }
            
            isResolving = false
        }
    }
    
    private func checkMarkerFile(at path: String) {
        // Use direct path check - with full disk access, we don't need security-scoped access
        let url = URL(fileURLWithPath: path)
        let markerManager = FolderMarkerManager.shared
        
        // Check if marker file exists using the project name
        hasMarkerFile = markerManager.markerFileExists(in: url, projectName: folder.name)
        
        // Also verify by reading the projectID from the marker file if it exists
        if let markerURL = markerManager.findMarkerFile(in: url) {
            if let markerProjectID = markerManager.readProjectID(from: markerURL),
               markerProjectID == folder.id {
                // Marker file matches this project
                hasMarkerFile = true
            } else {
                // Marker file exists but doesn't match - might be from another project
                hasMarkerFile = false
            }
        }
    }
    
    private func testBookmark() {
        let result = viewModel.testBookmark(for: folder)
        bookmarkTestMessage = result.message
        showingBookmarkTest = true
    }
    
    private func resolveFolder(showPrompt: Bool = true) {
        isResolving = true
        
        let result = viewModel.resolveAndUpdate(folder, showPrompt: showPrompt)
        
        syncStatus = result.syncStatus
        isOutOfSync = !result.syncStatus.isSynced && result.syncStatus.actualPath != nil
        
        if let url = result.url {
            resolvedPath = url.path
        } else {
            resolvedPath = folder.folderPath
        }
        
        isResolving = false
    }
}

struct AddFolderSheet: View {
    @Binding var folderName: String
    let onAdd: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Project Folder")
                .font(.title2)
                .fontWeight(.semibold)
            
            TextField("Folder Name (optional)", text: $folderName)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                
                Button("Select Folder") {
                    onAdd()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ProjectFolder.self, inMemory: true)
}
