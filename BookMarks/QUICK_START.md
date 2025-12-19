# BookMarks - Quick Start Guide

## Getting Started

### First Time Setup

1. **Open in Xcode**
   ```bash
   open BookMarks.xcodeproj
   ```

2. **Disable App Sandbox**
   - Select project → Target "BookMarks"
   - Go to "Signing & Capabilities"
   - Remove "App Sandbox" if present
   - Verify `BookMarks.entitlements` has sandbox commented out

3. **Build & Run**
   - Clean: `Shift + Cmd + K`
   - Build: `Cmd + B`
   - Run: `Cmd + R`

## Basic Usage

### Adding a Project Folder

1. Click the **"+"** button in the toolbar
2. Enter an optional folder name
3. Click **"Select Folder"**
4. Choose your project folder
5. Done! Folder is now tracked

### Understanding Status Indicators

| Icon | Meaning |
|------|---------|
| 🟢 Green Bookmark | Folder is in sync |
| 🟠 Orange Bookmark | Folder is out of sync |
| ⚠️ "Out of Sync" Badge | Path mismatch detected |
| 🔄 "Searching..." | Actively searching for folder |
| 🔍 "Locate" Button | Search failed, click to manually locate |

### When a Folder is Moved

The app automatically:
1. Detects the move (within 10 seconds)
2. Searches for the folder using bookmark or marker file
3. Updates the path in the database
4. Updates the bookmark and marker file

**You don't need to do anything!**

### Manual Location (If Needed)

If automatic search fails:
1. Click the **"Locate"** button
2. Select the folder from the file picker
3. App updates everything automatically

## Marker Files

Each tracked folder contains a file named `[ProjectName].DSBookmark`:
- **Visible in Finder** with custom icon
- **Searchable** - Find folders by searching for `.DSBookmark`
- **Contains metadata** - Project name, ID, creation date
- **Auto-updates** - Moves with folder, updates when relocated

## Troubleshooting

### Folder Shows "Out of Sync"

**Solution**: The app will automatically update. If it doesn't:
1. Click the folder row
2. Or right-click → "Resolve Folder"
3. Or right-click → "Update to Current Location"

### "Locate" Button Appears

**Solution**: 
1. Click "Locate"
2. Manually select the folder
3. App will update automatically

### Marker File Not Created

**Check**:
- App has full disk access (sandbox disabled)
- Folder is writable
- Check console for error messages

### Bookmark Shows as Stale

**Solution**: This is normal when folders move. The app will:
1. Try to resolve the bookmark
2. Search for marker files if bookmark fails
3. Update everything when found

## Keyboard Shortcuts

- **Cmd + N**: Add new folder (if implemented)
- **Delete**: Remove selected folder (swipe left or context menu)

## Context Menu Actions

Right-click any folder for:
- **Test Bookmark**: Verify bookmark is working
- **Resolve Folder**: Manually trigger resolution
- **Update to Current Location**: Force update if out of sync
- **Create Marker File**: Create marker file if missing

## Tips

1. **Name Your Folders**: Use descriptive names for easier identification
2. **Wait for Auto-Update**: The app checks every 10 seconds - be patient
3. **Use Marker Files**: Search Finder for `.DSBookmark` to find tracked folders
4. **Check Console**: View Xcode console for detailed operation logs

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed technical information.

## Support

For issues or questions, check:
- Console logs in Xcode
- Sync status indicators
- Error messages in the app

