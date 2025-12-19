# BookMarks - Project Folder Tracker

A macOS application that tracks project folders using security-scoped bookmarks and custom marker files, maintaining access even after folders are moved.

## Features

- **Persistent Tracking**: Tracks folders even after they're moved to different locations
- **Automatic Updates**: Automatically updates folder paths when moves are detected
- **Visual Indicators**: Real-time sync status, bookmark status, and search indicators
- **Marker Files**: Creates searchable `.DSBookmark` files with custom icons
- **Robust Resolution**: Multiple fallback mechanisms (path → bookmark → marker search → manual)
- **Full Disk Access**: No sandbox restrictions for seamless file operations

## Project Structure

The project follows MVC (Model-View-Controller) architecture:

```
BookMarks/
├── BookMarksApp.swift          # App entry point
├── Models/                     # Data models
│   └── ProjectFolder.swift
├── Views/                      # UI components
│   ├── ContentView.swift
│   └── ManualLocateSheet.swift
├── ViewModels/                 # Business logic
│   └── ProjectFolderViewModel.swift
├── Services/                   # Service layer
│   ├── BookmarkManager.swift
│   ├── FolderMarkerManager.swift
│   ├── SecurityScopedResource.swift
│   └── PermissionHelper.swift
└── Resources/                  # Assets & config
    ├── Assets.xcassets/
    ├── Info.plist
    └── BookMarks.entitlements
```

## How It Works

### Adding a Folder

1. Click the "+" button
2. Select a folder from the file picker
3. The app:
   - Creates a security-scoped bookmark
   - Stores folder information in SwiftData
   - Creates a `[ProjectName].DSBookmark` marker file
   - Sets custom icon on the marker file

### Tracking Moved Folders

The app uses a three-tier resolution system:

1. **Stored Path**: Checks if folder exists at stored location
2. **Bookmark Resolution**: Resolves security-scoped bookmark to find new location
3. **Marker File Search**: Searches for `.DSBookmark` files by projectID
4. **Manual Locate**: Prompts user if automatic resolution fails

### Automatic Updates

- Checks sync status every 10 seconds
- Automatically updates paths when folders are moved
- Updates bookmarks and marker files to new locations
- Shows visual indicators for sync status

### Marker Files

Each tracked folder contains a marker file:
- **Name**: `[ProjectName].DSBookmark`
- **Icon**: Custom devspace-icon
- **Content**: Project metadata (name, ID, dates)
- **Purpose**: Searchable in Finder, enables folder discovery

## Setup

### 1. Disable App Sandbox

The app requires full disk access:

1. Open project in Xcode
2. Select app target → "Signing & Capabilities"
3. Remove "App Sandbox" capability if present
4. Verify `BookMarks.entitlements` has sandbox disabled

### 2. Build & Run

1. Clean build folder (Shift+Cmd+K)
2. Build (Cmd+B)
3. Run (Cmd+R)

## Usage

### Adding Folders

1. Click "+" button
2. Select folder from picker
3. Optionally provide a custom name
4. Folder is now tracked

### Viewing Status

- **Green bookmark** = In sync
- **Orange bookmark** = Out of sync
- **"Out of Sync" badge** = Path mismatch
- **"Searching..."** = Actively searching
- **"Locate" button** = Manual locate available

### Manual Location

If automatic search fails:
1. Click "Locate" button
2. Select folder from file picker
3. App updates path automatically

### Context Menu

Right-click any folder for:
- Test Bookmark
- Resolve Folder
- Update to Current Location (if out of sync)
- Create Marker File

## Technical Details

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed technical documentation.

## Requirements

- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+
- Full disk access (no sandbox)

## License

Copyright © 2025. All rights reserved.
