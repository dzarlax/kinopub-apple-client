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
</array>
```

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

## Important Notes

- Background downloads work only on physical devices
- iOS limits background execution time
- Users can disable background refresh per app
- Respect low power mode and cellular data settings
- Background tasks may be throttled by the system

## Debugging

Add these debug flags in scheme for detailed logging:

```
-BGTaskSchedulerDevelopmentMode YES
```

This enables background task simulation in Xcode. 