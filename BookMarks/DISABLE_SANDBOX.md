# How to Disable App Sandbox in Xcode

The app needs **full disk access** to create marker files. Follow these steps to disable the sandbox:

## Step 1: Remove App Sandbox Capability

1. Open your project in Xcode
2. Select your project in the navigator (top item)
3. Select your **app target** (BookMarks)
4. Click on the **"Signing & Capabilities"** tab
5. Look for **"App Sandbox"** in the capabilities list
6. If you see it, click the **"X"** button next to it to remove it
7. If you don't see it, the sandbox is already disabled

## Step 2: Verify Entitlements

1. Still in "Signing & Capabilities", scroll down to see entitlements
2. Or go to **"Build Settings"** tab
3. Search for **"Code Signing Entitlements"**
4. Make sure it points to `BookMarks/BookMarks.entitlements`
5. The entitlements file should have the sandbox commented out (which it does)

## Step 3: Clean and Rebuild

1. In Xcode menu: **Product → Clean Build Folder** (Shift+Cmd+K)
2. **Product → Build** (Cmd+B)
3. **Product → Run** (Cmd+R)

## Step 4: Verify It's Working

After rebuilding, try adding a folder again. The marker files should be created without permission errors.

## Alternative: If Sandbox Must Stay Enabled

If you need to keep the sandbox enabled (for App Store distribution), you'll need to:

1. Request Full Disk Access from the user
2. Have the user manually grant it in System Settings → Privacy & Security → Full Disk Access
3. The app will need special entitlements from Apple

For development, **disabling the sandbox is the easiest solution**.

