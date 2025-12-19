# BookMarks - Project Structure

## Directory Organization (MVC Pattern)

```
BookMarks/
│
├── BookMarksApp.swift                    # App entry point & SwiftData container
│
├── Models/                               # Data Models
│   └── ProjectFolder.swift               # SwiftData model for tracked folders
│
├── Views/                                # User Interface
│   ├── ContentView.swift                 # Main app view with folder list
│   └── ManualLocateSheet.swift          # Sheet for manual folder location
│
├── ViewModels/                           # Business Logic & State
│   └── ProjectFolderViewModel.swift     # Folder management logic
│
├── Services/                             # Service Layer
│   ├── BookmarkManager.swift            # Security-scoped bookmark operations
│   ├── FolderMarkerManager.swift        # Marker file (.DSBookmark) operations
│   ├── SecurityScopedResource.swift     # Resource access lifecycle management
│   └── PermissionHelper.swift           # System permission utilities
│
└── Resources/                            # Assets & Configuration
    ├── Assets.xcassets/                  # Images, icons, colors
    │   ├── AppIcon.appiconset/
    │   ├── AccentColor.colorset/
    │   └── devspace-icon.imageset/      # Custom marker file icon
    ├── Info.plist                        # App metadata
    └── BookMarks.entitlements           # App entitlements (full disk access)
```

## File Responsibilities

### App Entry Point
- **BookMarksApp.swift**: Configures SwiftUI app, sets up SwiftData container

### Models
- **ProjectFolder.swift**: 
  - SwiftData `@Model` class
  - Stores folder metadata (name, path, bookmark, ID, dates)
  - Persisted automatically by SwiftData

### Views
- **ContentView.swift**:
  - Main application window
  - Folder list with status indicators
  - Add/delete folder actions
  - Sync status display
  - Search UI and manual locate

- **ManualLocateSheet.swift**:
  - Modal sheet for manual folder selection
  - File picker integration
  - Updates folder path on selection

### ViewModels
- **ProjectFolderViewModel.swift**:
  - `@Observable` class for state management
  - Folder CRUD operations
  - Sync status checking
  - Automatic path updates
  - Marker file search coordination

### Services

- **BookmarkManager.swift**:
  - Creates security-scoped bookmarks
  - Resolves bookmarks to URLs
  - Folder existence checking
  - Three-tier resolution logic (path → bookmark → prompt)

- **FolderMarkerManager.swift**:
  - Creates/updates/removes marker files
  - Sets custom icons on marker files
  - Searches for marker files (Spotlight + FileManager)
  - Reads marker file metadata

- **SecurityScopedResource.swift**:
  - Wraps security-scoped resource access
  - Automatic cleanup in `deinit`
  - `withAccess()` pattern for safe operations

- **PermissionHelper.swift**:
  - Checks full disk access status
  - Opens System Settings
  - Shows permission request dialogs

## Data Flow

### Adding Folder
```
ContentView
  ↓
ProjectFolderViewModel.addProjectFolder()
  ├─→ BookmarkManager.createBookmark()
  ├─→ SwiftData.save()
  └─→ FolderMarkerManager.createMarkerFile()
```

### Checking Status
```
ContentView (periodic check)
  ↓
ProjectFolderViewModel.checkSyncStatus()
  ├─→ BookmarkManager.resolveBookmark()
  └─→ Returns SyncStatus
```

### Resolving Moved Folder
```
ProjectFolderViewModel.resolveAndUpdate()
  ├─→ BookmarkManager.resolveProjectFolder()
  ├─→ FolderMarkerManager.findFolderByMarker() (if needed)
  ├─→ Updates SwiftData
  ├─→ Creates new bookmark
  └─→ Updates marker file
```

## Dependencies

### External Frameworks
- **SwiftUI**: UI framework
- **SwiftData**: Data persistence
- **AppKit**: File dialogs, workspace operations
- **Foundation**: File operations, URLs
- **CoreServices**: Spotlight/MDQuery search

### Internal Dependencies
- Models → None (pure data)
- Views → ViewModels, Models
- ViewModels → Services, Models
- Services → Foundation, AppKit, CoreServices

## Key Design Patterns

1. **MVC Architecture**: Clear separation of concerns
2. **Service Layer**: Reusable business logic
3. **Observable Pattern**: SwiftUI state management
4. **Resource Management**: RAII pattern for security-scoped resources
5. **Async/Await**: Non-blocking operations
6. **Error Handling**: Try-catch with graceful degradation

## Testing Considerations

### Unit Testable
- Services (BookmarkManager, FolderMarkerManager)
- ViewModels (with mock services)

### Integration Testable
- Full resolution flow
- Marker file search
- Sync status detection

### UI Testable
- Folder addition/deletion
- Status indicators
- Manual locate flow

## Build Configuration

### Entitlements
- App Sandbox: **Disabled** (for full disk access)
- Bookmarks: Enabled (app-scope, document-scope)

### Info.plist
- Standard macOS app configuration
- High resolution capable
- Principal class: NSApplication

### Assets
- App icon set
- Accent color
- Custom devspace-icon for marker files

## Notes

- All Swift files are in the same module, so imports work automatically
- SwiftData handles schema migrations automatically
- File organization follows standard iOS/macOS MVC patterns
- Services are stateless singletons for easy testing

