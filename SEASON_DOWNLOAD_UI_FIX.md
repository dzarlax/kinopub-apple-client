# Season Download UI Fix - Group Expansion Issue

## Problem Description

When tapping to expand/collapse a season download group, the wrong group would expand/collapse. For example, clicking on the second series would expand the first series instead.

## Root Cause Analysis

The issue was caused by SwiftUI's view identity confusion in complex `List` + `ForEach` structures with stateful views. Specifically:

1. **Closure Capture Issue**: The `onToggleExpansion` closures were capturing `seasonGroup.id` at the wrong time
2. **SwiftUI View Identity**: SwiftUI was not properly tracking which view corresponds to which data model
3. **State Synchronization**: The expansion state was not properly synchronized between the data model and the UI

## Implemented Solutions

### 1. Fixed Closure Capture in DownloadsView

**Before:**
```swift
ForEach(catalog.seasonGroups, id: \.id) { seasonGroup in
  SeasonDownloadGroupView(
    seasonGroup: seasonGroup,
    onToggleExpansion: {
      catalog.toggleSeasonGroupExpansion(groupId: seasonGroup.id) // Wrong capture
    }
  )
}
```

**After:**
```swift
ForEach(catalog.seasonGroups, id: \.id) { seasonGroup in
  let groupId = seasonGroup.id // Capture ID in local variable
  SeasonDownloadGroupView(
    seasonGroup: seasonGroup,
    onToggleExpansion: {
      print("🔄 Toggle expansion for group: \(groupId)")
      catalog.toggleSeasonGroupExpansion(groupId: groupId) // Correct capture
    }
  )
  .id(seasonGroup.id) // Explicit SwiftUI identity
}
```

### 2. Added Local State Management in SeasonDownloadGroupView

**Added:**
```swift
struct SeasonDownloadGroupView: View {
  // ... existing properties
  
  // Local state for reliable UI updates
  @State private var localIsExpanded: Bool = false
  
  var body: some View {
    VStack(spacing: 0) {
      groupHeader
      
      // Use local state for display
      if localIsExpanded {
        episodesList
      }
    }
    .onAppear {
      localIsExpanded = seasonGroup.isExpanded
    }
    .onChange(of: seasonGroup.isExpanded) { newValue in
      if localIsExpanded != newValue {
        localIsExpanded = newValue
      }
    }
  }
}
```

### 3. Enhanced Button Actions with Immediate UI Feedback

**Updated:**
```swift
Button(action: {
  print("🔄 Local toggle for group: \(seasonGroup.id), current state: \(localIsExpanded)")
  localIsExpanded.toggle() // Immediate UI update
  onToggleExpansion() // Then notify data model
}) {
  Image(systemName: localIsExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
    .font(.title)
    .foregroundColor(.blue)
}
```

### 4. Added Comprehensive Logging for Debugging

**In SeasonDownloadManager:**
```swift
@MainActor
public func toggleGroupExpansion(groupId: String) {
  Logger.kit.info("[SEASON DOWNLOAD] Toggle expansion requested for group: \(groupId)")
  
  if let index = seasonGroups.firstIndex(where: { $0.id == groupId }) {
    let wasExpanded = seasonGroups[index].isExpanded
    seasonGroups[index].isExpanded.toggle()
    let isNowExpanded = seasonGroups[index].isExpanded
    
    Logger.kit.info("[SEASON DOWNLOAD] Group \(groupId) at index \(index): \(wasExpanded) -> \(isNowExpanded)")
    Logger.kit.info("[SEASON DOWNLOAD] Group title: \(seasonGroups[index].seriesTitle) - \(seasonGroups[index].seasonTitle)")
    
    // Log all groups state for debugging
    for (i, group) in seasonGroups.enumerated() {
      Logger.kit.info("[SEASON DOWNLOAD] Group \(i): \(group.id) (\(group.seriesTitle)) - expanded: \(group.isExpanded)")
    }
    
    debouncedSave()
  } else {
    Logger.kit.error("[SEASON DOWNLOAD] Group with ID \(groupId) not found!")
    // Log available groups for debugging
    for (i, group) in seasonGroups.enumerated() {
      Logger.kit.info("[SEASON DOWNLOAD] - \(i): \(group.id) (\(group.seriesTitle))")
    }
  }
}
```

## Technical Improvements

### 1. Explicit SwiftUI Identity
- Added `.id(seasonGroup.id)` to ensure SwiftUI properly tracks each view
- This prevents view recycling confusion

### 2. Local State Pattern
- Introduced `@State private var localIsExpanded` for immediate UI responsiveness
- Synchronized with data model state using `onAppear` and `onChange`

### 3. Proper Closure Capture
- Captured `groupId` in local variable before creating closures
- Prevents late binding issues in SwiftUI closures

### 4. Enhanced Debugging
- Added print statements and Logger calls to track user interactions
- Comprehensive state logging for troubleshooting

## Testing Guidelines

### Manual Testing Steps

1. **Create Multiple Season Downloads**: Download 2-3 different TV series seasons
2. **Test Expansion**: Click on each group's expand button and verify correct group expands
3. **Test Info Area**: Click on the series info area and verify correct group expands
4. **Mixed State Testing**: Have some groups expanded, some collapsed, verify correct behavior
5. **Log Verification**: Check Console.app for proper logging of group IDs and states

### Debug Log Monitoring

Look for these log patterns in Console.app:
```
[SEASON DOWNLOAD] Toggle expansion requested for group: season_123_1
[SEASON DOWNLOAD] Group season_123_1 at index 0: false -> true
[SEASON DOWNLOAD] Group title: Breaking Bad - Season 1
```

### Common Issues to Watch For

1. **Wrong Group Expanding**: If still occurring, check closure capture in ForEach
2. **UI Lag**: Local state should provide immediate visual feedback
3. **State Desync**: Monitor onChange callbacks for proper synchronization

## Performance Impact

- **Minimal**: Added local state has negligible memory overhead
- **Improved Responsiveness**: Immediate UI updates without waiting for data model
- **Better Debugging**: Enhanced logging helps identify issues quickly

## Future Improvements

1. **Animation**: Add smooth expand/collapse animations
2. **Persistence**: Remember expansion state across app restarts
3. **Accessibility**: Add VoiceOver support for expansion state
4. **Gesture Recognition**: Support swipe gestures for expand/collapse

## Conclusion

This fix addresses the core SwiftUI identity and closure capture issues that caused incorrect group expansion behavior. The combination of explicit view identity, local state management, and proper closure capture ensures reliable and responsive UI behavior.

The enhanced logging provides excellent debugging capabilities for future issues, and the local state pattern can be applied to other similar UI components in the app. 