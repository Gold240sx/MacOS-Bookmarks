# BookMarks - Architecture & Functionality

## Overview

BookMarks is a macOS application that tracks project folders on your hard drive using a combination of security-scoped bookmarks and custom marker files. The app maintains persistent access to folders even after they're moved, automatically updating their locations when detected.

## Project Structure (MVC Pattern)

```
BookMarks/
├── BookMarksApp.swift          # App entry point
├── Models/
│   └── ProjectFolder.swift     # SwiftData model for project folders
├── Views/
│   ├── ContentView.swift       # Main UI with folder list
│   └── ManualLocateSheet.swift # Sheet for manual folder location
├── ViewModels/
│   └── ProjectFolderViewModel.swift  # Business logic & state management
├── Services/
│   ├── BookmarkManager.swift          # Security-scoped bookmark handling
│   ├── FolderMarkerManager.swift      # Marker file creation & search
│   ├── SecurityScopedResource.swift   # Resource access management
│   └── PermissionHelper.swift         # Permission checking utilities
└── Resources/
    ├── Assets.xcassets/        # App icons and images
    ├── Info.plist              # App configuration
    └── BookMarks.entitlements  # App entitlements (full disk access)
```

## Core Components

### Models

#### ProjectFolder (SwiftData Model)
- **Purpose**: Persistent data model for tracked folders
- **Properties**:
  - `id: UUID` - Unique identifier
  - `name: String` - Display name
  - `folderPath: String` - Current stored path
  - `bookmarkData: Data?` - Security-scoped bookmark data
  - `createdAt: Date` - Creation timestamp
- **Storage**: SwiftData automatically persists to disk

### Views

#### ContentView
- **Purpose**: Main application interface
- **Features**:
  - Lists all tracked project folders
  - Shows sync status indicators
  - Displays bookmark and marker file status
  - Provides context menu actions
  - Handles folder addition/deletion

#### ProjectFolderRow
- **Purpose**: Individual folder row component
- **Features**:
  - Visual sync status indicators
  - Bookmark status icons
  - Path display (with strikethrough when out of sync)
  - Searching indicator
  - Manual locate button

#### ManualLocateSheet
- **Purpose**: Allows user to manually locate a missing folder
- **Features**:
  - File picker dialog
  - Updates folder path when selected

### ViewModels

#### ProjectFolderViewModel
- **Purpose**: Business logic and state management
- **Key Functions**:
  - `addProjectFolder()` - Creates new tracked folder
  - `checkSyncStatus()` - Determines if folder is in sync
  - `resolveAndUpdate()` - Resolves folder location and updates if moved
  - `searchForFolderByMarker()` - Async search for marker files
  - `updateFolderPathManually()` - Manual path update
  - `ensureMarkerFile()` - Creates marker file if missing

### Services

#### BookmarkManager
- **Purpose**: Manages security-scoped bookmarks
- **Key Functions**:
  - `createBookmark()` - Creates security-scoped bookmark from URL
  - `resolveBookmark()` - Converts bookmark data back to URL
  - `resolveProjectFolder()` - Fallback resolution (path → bookmark → prompt)
  - `folderExists()` - Checks if folder exists at path
  - `promptForFolder()` - Shows file picker dialog

#### FolderMarkerManager
- **Purpose**: Manages marker files (`.DSBookmark` files)
- **Key Functions**:
  - `createMarkerFile()` - Creates `[ProjectName].DSBookmark` file
  - `updateMarkerFile()` - Updates existing marker file
  - `removeMarkerFile()` - Deletes marker file
  - `findFolderByMarker()` - Searches for folder by projectID
  - `markerFileExists()` - Checks if marker file exists
  - `setCustomIcon()` - Sets devspace-icon as file icon

#### SecurityScopedResource
- **Purpose**: Manages security-scoped resource access lifecycle
- **Key Functions**:
  - `startAccessing()` - Begins security-scoped access
  - `stopAccessing()` - Ends security-scoped access
  - `withAccess()` - Executes block with automatic cleanup

#### PermissionHelper
- **Purpose**: Checks and requests system permissions
- **Key Functions**:
  - `checkFullDiskAccess()` - Verifies full disk access
  - `openFullDiskAccessSettings()` - Opens System Settings
  - `requestFullDiskAccess()` - Shows permission request dialog

## How It Works

### 1. Adding a Project Folder

**Flow:**
1. User clicks "+" button → `ContentView.addFolder()`
2. `NSOpenPanel` prompts for folder selection
3. `ProjectFolderViewModel.addProjectFolder()` is called:
   - Creates security-scoped bookmark
   - Creates SwiftData `ProjectFolder` instance
   - Saves to database
   - Creates marker file (`[ProjectName].DSBookmark`) in folder
   - Sets custom icon on marker file

**Result:**
- Folder tracked in SwiftData
- Bookmark stored for persistent access
- Marker file created for searchability

### 2. Tracking Folder Location

**Three-Tier Resolution System:**

1. **Stored Path Check**
   - First checks if folder exists at stored path
   - Fast, no security-scoped access needed

2. **Bookmark Resolution**
   - If stored path doesn't exist, resolves bookmark
   - Bookmark tracks folder even after moves
   - Uses security-scoped access

3. **Marker File Search**
   - If bookmark is stale, searches for marker file
   - Uses Spotlight (MDQuery) first (fast if indexed)
   - Falls back to FileManager recursive search
   - Searches Desktop, Documents, Downloads, Home
   - Reads marker file to match projectID

4. **User Prompt** (if all else fails)
   - Shows file picker dialog
   - User manually locates folder
   - Updates path, bookmark, and marker file

### 3. Sync Status Detection

**Process:**
1. `checkSyncStatus()` compares:
   - Stored path vs. actual location (from bookmark or marker)
2. Determines sync state:
   - **Synced**: Stored path matches actual location
   - **Out of Sync**: Paths differ (folder was moved)
   - **Not Found**: Cannot resolve location

**Visual Indicators:**
- Green bookmark icon = In sync
- Orange bookmark icon = Out of sync
- "Out of Sync" badge = Path mismatch detected
- "Searching..." indicator = Actively searching
- "Locate" button = Search failed, manual locate available

### 4. Automatic Updates

**When Folder is Moved:**
1. Periodic check (every 10 seconds) detects path mismatch
2. `resolveAndUpdate()` is called:
   - Resolves to new location (via bookmark or marker search)
   - Updates `folderPath` in SwiftData
   - Creates new bookmark for new location
   - Updates marker file in new location
3. UI automatically refreshes with new path

**Background Process:**
- Runs in `Task` to avoid blocking UI
- Shows "Searching..." indicator during search
- Automatically updates when found

### 5. Marker Files

**Purpose:**
- Searchable in Finder
- Contains project metadata (name, ID, dates)
- Custom icon (devspace-icon) for visual identification
- Enables folder discovery when bookmark fails

**File Format:**
- **Name**: `[ProjectName].DSBookmark`
- **Extension**: `.DSBookmark`
- **Format**: XML Property List
- **Content**:
  ```xml
  <dict>
    <key>projectName</key>
    <string>Project Name</string>
    <key>projectID</key>
    <string>UUID</string>
    <key>createdBy</key>
    <string>BookMarks</string>
    <key>createdAt</key>
    <string>ISO8601 Date</string>
  </dict>
  ```

**Search Process:**
1. Spotlight query for `.DSBookmark` files
2. If not found, FileManager recursive search
3. Reads each marker file to match projectID
4. Returns parent folder URL

### 6. Security & Permissions

**Full Disk Access:**
- App runs without sandbox (full disk access)
- Allows creating marker files anywhere
- No permission prompts for file operations

**Security-Scoped Bookmarks:**
- Created when folder is added
- Updated when folder moves
- Provides persistent access across app restarts
- Handles folder moves automatically

**Resource Management:**
- `SecurityScopedResource` ensures proper cleanup
- Access started before operations
- Access stopped after operations
- Automatic cleanup in `deinit`

## Data Flow

### Adding Folder
```
User Action
  ↓
NSOpenPanel (file picker)
  ↓
ProjectFolderViewModel.addProjectFolder()
  ├─→ BookmarkManager.createBookmark()
  ├─→ SwiftData.save()
  └─→ FolderMarkerManager.createMarkerFile()
      └─→ setCustomIcon()
```

### Checking Sync Status
```
Periodic Check (every 10s)
  ↓
ProjectFolderViewModel.checkSyncStatus()
  ├─→ BookmarkManager.resolveBookmark()
  ├─→ BookmarkManager.folderExists()
  └─→ Returns SyncStatus
      ├─→ If out of sync: auto-update
      └─→ If needs search: start search
```

### Resolving Moved Folder
```
Folder Missing
  ↓
resolveAndUpdate()
  ├─→ Try stored path
  ├─→ Try bookmark resolution
  ├─→ Try marker file search
  │   ├─→ Spotlight (MDQuery)
  │   └─→ FileManager recursive
  └─→ If found:
      ├─→ Update SwiftData
      ├─→ Create new bookmark
      └─→ Update marker file
```

## Key Features

### 1. Persistent Tracking
- Folders tracked even after moves
- Automatic location updates
- No manual intervention needed

### 2. Visual Feedback
- Real-time sync status
- Searching indicators
- Out-of-sync warnings
- Bookmark and marker file status

### 3. Robust Resolution
- Multiple fallback mechanisms
- Automatic search when needed
- Manual locate option
- Handles edge cases gracefully

### 4. Searchability
- Marker files searchable in Finder
- Custom icon for easy identification
- Named after project for clarity

### 5. Performance
- Efficient periodic checks (10s interval)
- Async operations for UI responsiveness
- Cached bookmark resolution
- Limited search depth (5 levels)

## Technical Details

### SwiftData Integration
- Uses `@Model` macro for persistence
- Automatic schema management
- Query-based data fetching
- Context-based updates

### Concurrency
- `@MainActor` for UI updates
- `Task.detached` for background searches
- Async/await for non-blocking operations
- Proper actor isolation

### Error Handling
- Try-catch for file operations
- Graceful degradation on failures
- User-friendly error messages
- Logging for debugging

### File System
- Direct file access (no sandbox)
- Atomic file writes
- Proper permission checks
- Resource cleanup

## Future Enhancements

Potential improvements:
- Spotlight indexing for faster searches
- Batch folder operations
- Folder groups/categories
- Export/import folder lists
- Cloud sync support
- Folder activity monitoring

