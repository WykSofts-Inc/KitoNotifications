# KitoNotifications

**[Documentation](https://wyksofts-inc.github.io/KitoNotifications/documentation/kitonotifications/)**

Local notifications and an in-app notification centre in SwiftUI: permission (including
provisional), scheduling, actions, the badge, and a delegate that shows notifications **while
your app is open** — plus an inbox, in-app banners, a priming screen and a settings screen with
quiet hours. Part of the [Kito](https://github.com/WykSofts-Inc/KitoDevKit) ecosystem.

## Show notifications while the app is open

Without a `UNUserNotificationCenterDelegate`, iOS drops notifications that arrive in the
foreground. Install KitoNotifications' delegate before the first scene appears:

```swift
@main
struct MyApp: App {
    init() { KitoNotificationCenter.shared.install() }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

Foreground notifications then show a banner, sound and badge, like when the app is closed
(`foregroundPresentation` changes that). `install()` replaces any delegate you set; if you keep
your own, return `presentationOptions(for:)` from `willPresent` and call `handle(_:)` from
`didReceive`.

## Ask, schedule, react

```swift
let center = KitoNotificationCenter.shared
await center.requestAuthorization()                    // or (provisional: true) — no prompt, delivered quietly

center.setCategories([
    KitoNotificationCategory("message", actions: [.reply(placeholder: "Reply to Grace")]),
    KitoNotificationCategory("order", actions: [KitoNotificationAction("track", title: "Track", opensApp: true)]),
])

try await center.schedule(KitoLocalNotification(
    title: "Mama's Kitchen", body: "Your order is on the way",
    trigger: .after(10), categoryID: "order"))
// .immediately, .after(seconds), .at(date), .daily(hour:minute:), .weekly(weekday:hour:minute:), .every(seconds)

center.onTap { response in router.open(response.userInfo["orderID"]) }
center.onAction("reply") { response in send(response.text) }
await center.setBadge(3)
await center.refresh()                                 // center.pending, center.delivered
```

## In-app notification centre

```swift
@State private var items: [KitoInboxNotification] = …

KitoNotificationInbox($items, grouping: .todayAndEarlier) { item in open(item) }

// Handle a row's action button too — `onAction:` goes before the trailing `onOpen`:
KitoNotificationInbox($items, onAction: { item in reply(to: item) }) { item in open(item) }
```

Today / Earlier (or `.byDay`) sections, unread dots, filter chips, swipe to mark read or
delete, Mark all read, and an empty state. `KitoNotificationRow` and `KitoInbox` (grouping,
filtering, unread counts, relative times) are there to build your own.

## In-app banners

```swift
ContentView()
    .kitoNotificationBanner($incoming, style: .card)      // .system, .card, .island
    .kitoNotificationBanners(from: center)                  // one for each foreground notification
```

They drop from the top, count down, swipe up to dismiss, and call `onTap`.

## Priming and settings

```swift
KitoNotificationPrimingView { status in finishOnboarding() }

KitoNotificationSettingsView($preferences, authorization: center.authorization)
```

`KitoNotificationPreferences` holds per-channel switches, quiet hours (`KitoQuietHours`, which may
cross midnight), previews, sounds and badges. Set `center.preferences` and foreground
notifications on a switched-off channel, or during quiet hours, land silently in Notification
Centre (time-sensitive ones can still break through).

## Migrating to 0.2

- `KitoNotificationChannel` is now `KitoNotificationChannelSetting`, and `KitoQuietHoursDial` is now
  `KitoNotificationQuietHoursDial`, so KitoNotifications can be imported next to KitoSettings
  (which has its own `KitoNotificationChannel` and `KitoQuietHoursDial`) without "ambiguous use"
  errors. `KitoNotificationPreferences.channels` keeps its name.
- `KitoNotificationInbox`'s trailing closure is now always `onOpen`. In 0.1 it bound to `onAction`
  (with a compiler warning). Labelled calls — `onOpen: …, onAction: …` — compile as before.

## Installation

```swift
.package(url: "https://github.com/WykSofts-Inc/KitoNotifications.git", from: "0.2.0")
```

Requires iOS 17 and KitoCore 1.1.0. Time-sensitive delivery needs the Time Sensitive
Notifications capability; everything else needs no Info.plist keys.

## License

MIT — see [LICENSE](LICENSE).
