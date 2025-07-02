# Background Downloads Info.plist Configuration

## Required Info.plist Changes

Add the following entries to your `Info.plist` file to enable background downloads:

### 1. Background Modes (Required)

```xml
<key>UIBackgroundModes</key>
<array>
    <string>background-processing</string>
    <string>background-fetch</string>
    <string>background-app-refresh</string>
</array>
```

### 2. Background Task Identifiers (Required for iOS 13+)

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.kinopub.background.downloads</string>
    <string>com.kinopub.background.sync</string>
    <string>com.kinopub.backgroundDownloads.*</string>
</array>
```

**Note:** The `com.kinopub.backgroundDownloads.*` identifier uses wildcard notation required for `BGContinuedProcessingTask` on iOS 26+ devices, which provides extended background processing time for larger video downloads.

### 3. Network Usage Description (Recommended)

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This app downloads video content in the background to provide offline viewing capabilities.</string>

<key>NSLocalNetworkUsageDescription</key>
<string>This app uses the local network to download content efficiently.</string>
```

### 4. Push Notifications (Optional - for download notifications)

```xml
<key>aps-environment</key>
<string>development</string>
```

## Complete Info.plist Example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Existing keys... -->
    
    <!-- Background Downloads Support -->
    <key>UIBackgroundModes</key>
    <array>
        <string>background-processing</string>
        <string>background-fetch</string>
        <string>background-app-refresh</string>
    </array>
    
    <key>BGTaskSchedulerPermittedIdentifiers</key>
    <array>
        <string>com.kinopub.background.downloads</string>
        <string>com.kinopub.background.sync</string>
        <string>com.kinopub.backgroundDownloads.*</string>
    </array>
    
    <!-- Network Usage -->
    <key>NSUserTrackingUsageDescription</key>
    <string>This app downloads video content in the background to provide offline viewing capabilities.</string>
    
    <key>NSLocalNetworkUsageDescription</key>
    <string>This app uses the local network to download content efficiently.</string>
    
    <!-- App Transport Security -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
</dict>
</plist>
```

## Testing Background Downloads

### 1. Device Settings
1. Go to **Settings** > **General** > **Background App Refresh**
2. Ensure it's enabled globally and for your app

### 2. Xcode Testing
1. Run app on device (not simulator)
2. Start a download
3. Background the app (Home button)
4. Use Xcode debug menu: **Debug** > **Simulate Background App Refresh**

### 3. Console Monitoring
Use Console.app to monitor background task execution:
- Filter by process name: `KinoPub`
- Look for logs with `[BACKGROUND]` prefix

## Capabilities in Xcode

In Xcode project settings:

1. Select your target
2. Go to **Signing & Capabilities**
3. Add **Background Modes** capability
4. Enable:
   - ✅ Background fetch
   - ✅ Background processing

## BGContinuedProcessingTask Support (iOS 26+)

Starting with iOS 26, the app uses `BGContinuedProcessingTask` instead of `BGProcessingTask` for improved background processing:

### Benefits
- **Extended execution time**: Longer background processing for large video downloads
- **Live Activity progress**: Users can see download progress and cancel if needed
- **Better resource management**: System allocates resources more efficiently
- **GPU support**: Can request background GPU access if needed for video processing
- **Improved reliability**: Designed specifically for long-running operations like media downloads

### Key Features
- **Wildcard identifiers**: Uses `com.kinopub.backgroundDownloads.*` notation
- **Submission strategies**: 
  - `.queue` (default): Queues task to run as soon as possible
  - `.fail`: Fails immediately if system can't run task right away
- **Foreground submission**: Tasks must be submitted from foreground as result of user action
- **Progress reporting**: Required to avoid system termination
- **Resource requests**: Can request additional resources like GPU background access

### Automatic Fallback
- iOS 26+: Uses `BGContinuedProcessingTask` for optimal performance
- iOS 13-25: Falls back to `BGProcessingTask` for compatibility
- The app automatically detects iOS version and uses the appropriate task type

### Requirements
- Task identifier `com.kinopub.backgroundDownloads.*` must be declared in Info.plist
- Submission must happen from foreground (e.g., when user taps download button)
- Progress reporting implementation required for long-running tasks
- All existing Background App Refresh permissions still apply
- Works seamlessly with existing download infrastructure

## Important Notes

- Background downloads work only on physical devices
- iOS limits background execution time (extended on iOS 17+ with BGContinuedProcessingTask)
- Users can disable background refresh per app
- Respect low power mode and cellular data settings
- Background tasks may be throttled by the system

## Debugging

Add these debug flags in scheme for detailed logging:

```
-BGTaskSchedulerDevelopmentMode YES
```

This enables background task simulation in Xcode. 