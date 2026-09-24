# ``KitoNotifications``

Local notifications and an in-app notification centre for SwiftUI.

## Overview

KitoNotifications wraps `UNUserNotificationCenter` in an observable
``KitoNotificationCenter``: permission (including provisional), scheduling,
categories and actions, the badge, and a delegate that shows notifications while
your app is open. Without such a delegate, iOS drops notifications that arrive
in the foreground, so install it before the first scene appears.

```swift
@main
struct MyApp: App {
    init() { KitoNotificationCenter.shared.install() }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

Then ask for permission and schedule from any async context:

```swift
let center = KitoNotificationCenter.shared
await center.requestAuthorization()
try await center.schedule(KitoLocalNotification(
    title: "Mama's Kitchen", body: "Your order is on the way",
    trigger: .after(10), categoryID: "order"))
```

A ``KitoNotificationTrigger`` fires immediately, after a delay, at a date, or on a
daily, weekly, or fixed repeat. Register ``KitoNotificationCategory`` values with
``KitoNotificationAction`` buttons — including text replies — and react to taps
and actions with `onTap(_:)` and `onAction(_:_:)`.

For the in-app side, ``KitoNotificationInbox`` presents a list of
``KitoInboxNotification`` items with Today and Earlier sections, unread dots,
filter chips, and swipe actions; ``KitoNotificationBanner`` drops a banner from
the top of the screen; ``KitoNotificationPrimingView`` explains the value of
notifications before the system prompt; and ``KitoNotificationSettingsView`` edits
``KitoNotificationPreferences``, including per-channel switches and quiet hours.

## Topics

### Essentials

- ``KitoNotificationCenter``
- ``KitoNotificationAuthorization``

### Scheduling

- ``KitoLocalNotification``
- ``KitoNotificationTrigger``
- ``KitoInterruptionLevel``
- ``KitoScheduledNotification``

### Categories and Responses

- ``KitoNotificationCategory``
- ``KitoNotificationAction``
- ``KitoNotificationResponse``
- ``KitoNotificationEvent``

### Inbox

- ``KitoNotificationInbox``
- ``KitoNotificationRow``
- ``KitoNotificationAvatarView``
- ``KitoInboxEmptyState``
- ``KitoInboxNotification``
- ``KitoNotificationKind``
- ``KitoNotificationAvatar``
- ``KitoInbox``
- ``KitoInboxGroup``
- ``KitoInboxGrouping``
- ``KitoInboxFilter``
- ``KitoInboxSection``

### Banners

- ``KitoNotificationBanner``
- ``KitoNotificationBannerStyle``

### Priming and Settings

- ``KitoNotificationPrimingView``
- ``KitoNotificationSettingsView``
- ``KitoNotificationPreferences``
- ``KitoNotificationChannelSetting``
- ``KitoQuietHours``
- ``KitoNotificationQuietHoursDial``
