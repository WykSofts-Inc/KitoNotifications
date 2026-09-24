//
//  KitoLocalNotification.swift
//  KitoNotifications
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import UserNotifications

/// Whether, and how, the app may notify.
public enum KitoNotificationAuthorization: String, Equatable, Sendable {
    /// Not asked yet.
    case notDetermined
    /// Turned off in Settings.
    case denied
    /// Alerts, sounds and badges.
    case authorized
    /// Delivered quietly to Notification Centre until the person chooses.
    case provisional
    /// App Clips only.
    case ephemeral

    public init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized: self = .authorized
        case .provisional: self = .provisional
        case .ephemeral: self = .ephemeral
        @unknown default: self = .notDetermined
        }
    }

    /// Notifications will arrive (loudly or quietly).
    public var canNotify: Bool { self == .authorized || self == .provisional || self == .ephemeral }

    public var label: String {
        switch self {
        case .notDetermined: return "Not asked"
        case .denied: return "Off"
        case .authorized: return "On"
        case .provisional: return "Delivered quietly"
        case .ephemeral: return "Temporary"
        }
    }
}

/// When a local notification fires.
public enum KitoNotificationTrigger: Equatable, Sendable {
    /// Right away.
    case immediately
    /// Once, after this many seconds.
    case after(TimeInterval)
    /// Once, at this moment.
    case at(Date)
    /// Every day at this time.
    case daily(hour: Int, minute: Int)
    /// Every week on `weekday` (1 = Sunday … 7 = Saturday) at this time.
    case weekly(weekday: Int, hour: Int, minute: Int)
    /// Over and over, this many seconds apart (the system's minimum is 60).
    case every(TimeInterval)

    /// Whether it fires more than once.
    public var repeats: Bool {
        switch self {
        case .daily, .weekly, .every: return true
        case .immediately, .after, .at: return false
        }
    }

    /// The system trigger; `nil` means deliver now.
    public func makeTrigger(calendar: Calendar = .current) -> UNNotificationTrigger? {
        switch self {
        case .immediately:
            return nil
        case .after(let seconds):
            return UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        case .at(let date):
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        case .daily(let hour, let minute):
            return UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: Self.clamp(hour, 0...23), minute: Self.clamp(minute, 0...59)), repeats: true)
        case .weekly(let weekday, let hour, let minute):
            return UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: Self.clamp(hour, 0...23), minute: Self.clamp(minute, 0...59), weekday: Self.clamp(weekday, 1...7)), repeats: true)
        case .every(let seconds):
            return UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 60), repeats: true)
        }
    }

    /// "Now", "In 5 min", "Daily at 07:30", "Mondays at 09:00".
    public var summary: String {
        switch self {
        case .immediately: return "Now"
        case .after(let seconds): return "In \(Self.durationText(seconds))"
        case .at(let date): return date.formatted(date: .abbreviated, time: .shortened)
        case .daily(let hour, let minute): return "Daily at \(Self.clock(hour, minute))"
        case .weekly(let weekday, let hour, let minute):
            // The rest of the summary is English, so name the day in English too. A calendar
            // without a locale can fall back to short symbols ("Mon"), which read as "Mons".
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: "en_US_POSIX")
            let names = calendar.weekdaySymbols
            let name = names[Self.clamp(weekday, 1...7) - 1]
            return "\(name)s at \(Self.clock(hour, minute))"
        case .every(let seconds): return "Every \(Self.durationText(max(seconds, 60)))"
        }
    }

    static func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int { min(max(value, range.lowerBound), range.upperBound) }

    static func clock(_ hour: Int, _ minute: Int) -> String {
        String(format: "%02d:%02d", clamp(hour, 0...23), clamp(minute, 0...59))
    }

    static func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "\(total) s" }
        if total < 3_600 { return "\(total / 60) min" }
        if total < 86_400 { return total % 3_600 == 0 ? "\(total / 3_600) h" : "\(total / 3_600) h \((total % 3_600) / 60) min" }
        return "\(total / 86_400) d"
    }
}

/// How insistently a notification interrupts.
public enum KitoInterruptionLevel: Sendable {
    /// Quietly into Notification Centre.
    case passive
    /// The normal banner and sound.
    case active
    /// Breaks through Focus (needs the Time Sensitive Notifications capability).
    case timeSensitive

    var system: UNNotificationInterruptionLevel {
        switch self {
        case .passive: return .passive
        case .active: return .active
        case .timeSensitive: return .timeSensitive
        }
    }
}

/// A local notification to schedule.
public struct KitoLocalNotification: Identifiable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var body: String
    public var trigger: KitoNotificationTrigger
    /// Matches a `KitoNotificationCategory` to show its action buttons.
    public var categoryID: String?
    /// Groups related notifications into one stack.
    public var threadID: String?
    public var playsSound: Bool
    /// The app icon badge to set when it's delivered.
    public var badge: Int?
    public var interruption: KitoInterruptionLevel
    public var userInfo: [String: String]

    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil,
        body: String,
        trigger: KitoNotificationTrigger = .immediately,
        categoryID: String? = nil,
        threadID: String? = nil,
        playsSound: Bool = true,
        badge: Int? = nil,
        interruption: KitoInterruptionLevel = .active,
        userInfo: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.trigger = trigger
        self.categoryID = categoryID
        self.threadID = threadID
        self.playsSound = playsSound
        self.badge = badge
        self.interruption = interruption
        self.userInfo = userInfo
    }

    /// The system request.
    public func makeRequest(calendar: Calendar = .current) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle { content.subtitle = subtitle }
        content.body = body
        if let categoryID { content.categoryIdentifier = categoryID }
        if let threadID { content.threadIdentifier = threadID }
        if playsSound { content.sound = .default }
        if let badge { content.badge = NSNumber(value: badge) }
        content.interruptionLevel = interruption.system
        content.userInfo = userInfo
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger.makeTrigger(calendar: calendar))
    }
}

/// A button on a notification.
public struct KitoNotificationAction: Equatable, Sendable {
    public var id: String
    public var title: String
    public var systemImage: String?
    public var isDestructive: Bool
    /// Brings the app to the foreground when tapped.
    public var opensApp: Bool
    /// Requires the device to be unlocked.
    public var requiresUnlock: Bool
    /// Turns the action into a reply field with this placeholder.
    public var textInputPlaceholder: String?

    public init(
        _ id: String,
        title: String,
        systemImage: String? = nil,
        isDestructive: Bool = false,
        opensApp: Bool = false,
        requiresUnlock: Bool = false,
        textInputPlaceholder: String? = nil
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.isDestructive = isDestructive
        self.opensApp = opensApp
        self.requiresUnlock = requiresUnlock
        self.textInputPlaceholder = textInputPlaceholder
    }

    /// A reply field.
    public static func reply(_ id: String = "reply", title: String = "Reply", placeholder: String = "Message") -> KitoNotificationAction {
        KitoNotificationAction(id, title: title, systemImage: "arrowshape.turn.up.backward.fill", textInputPlaceholder: placeholder)
    }

    var options: UNNotificationActionOptions {
        var options: UNNotificationActionOptions = []
        if isDestructive { options.insert(.destructive) }
        if opensApp { options.insert(.foreground) }
        if requiresUnlock { options.insert(.authenticationRequired) }
        return options
    }

    func makeAction() -> UNNotificationAction {
        let icon = systemImage.map { UNNotificationActionIcon(systemImageName: $0) }
        if let textInputPlaceholder {
            return UNTextInputNotificationAction(identifier: id, title: title, options: options, icon: icon, textInputButtonTitle: "Send", textInputPlaceholder: textInputPlaceholder)
        }
        return UNNotificationAction(identifier: id, title: title, options: options, icon: icon)
    }
}

/// A named set of actions, attached to notifications through `categoryID`.
public struct KitoNotificationCategory: Equatable, Sendable {
    public var id: String
    public var actions: [KitoNotificationAction]
    /// Shown instead of the content when previews are hidden: "%u new messages".
    public var hiddenPreviewsPlaceholder: String?

    public init(_ id: String, actions: [KitoNotificationAction], hiddenPreviewsPlaceholder: String? = nil) {
        self.id = id
        self.actions = actions
        self.hiddenPreviewsPlaceholder = hiddenPreviewsPlaceholder
    }

    func makeCategory() -> UNNotificationCategory {
        if let hiddenPreviewsPlaceholder {
            return UNNotificationCategory(
                identifier: id,
                actions: actions.map { $0.makeAction() },
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: hiddenPreviewsPlaceholder,
                options: [.customDismissAction]
            )
        }
        return UNNotificationCategory(identifier: id, actions: actions.map { $0.makeAction() }, intentIdentifiers: [], options: [.customDismissAction])
    }
}

/// What the person did with a notification.
public struct KitoNotificationResponse: Equatable, Sendable {
    public var notificationID: String
    public var categoryID: String
    /// The action's id; `nil` for a plain tap on the notification.
    public var actionID: String?
    public var title: String
    public var body: String
    public var userInfo: [String: String]
    /// What they typed into a reply action.
    public var text: String?
    /// True when they swiped it away.
    public var isDismissal: Bool

    public init(notificationID: String, categoryID: String = "", actionID: String? = nil, title: String = "", body: String = "", userInfo: [String: String] = [:], text: String? = nil, isDismissal: Bool = false) {
        self.notificationID = notificationID
        self.categoryID = categoryID
        self.actionID = actionID
        self.title = title
        self.body = body
        self.userInfo = userInfo
        self.text = text
        self.isDismissal = isDismissal
    }

    public var isTap: Bool { actionID == nil && !isDismissal }
}

/// A notification that arrived while the app was open.
public struct KitoNotificationEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var notificationID: String
    public var title: String
    public var subtitle: String
    public var body: String
    public var categoryID: String
    public var threadID: String
    public var userInfo: [String: String]
    public var date: Date

    public init(id: UUID = UUID(), notificationID: String, title: String, subtitle: String = "", body: String, categoryID: String = "", threadID: String = "", userInfo: [String: String] = [:], date: Date = Date()) {
        self.id = id
        self.notificationID = notificationID
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.categoryID = categoryID
        self.threadID = threadID
        self.userInfo = userInfo
        self.date = date
    }
}

/// A pending or delivered notification, as listed by the system.
public struct KitoScheduledNotification: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var body: String
    public var categoryID: String
    /// When a pending one fires next (nil if unknown or already delivered).
    public var nextFireDate: Date?
    public var repeats: Bool
    /// When a delivered one arrived.
    public var deliveredAt: Date?

    public init(id: String, title: String, body: String, categoryID: String = "", nextFireDate: Date? = nil, repeats: Bool = false, deliveredAt: Date? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.categoryID = categoryID
        self.nextFireDate = nextFireDate
        self.repeats = repeats
        self.deliveredAt = deliveredAt
    }
}

extension Dictionary where Key == AnyHashable, Value == Any {
    /// Plain string pairs from a notification's `userInfo`.
    var kitoStrings: [String: String] {
        var result: [String: String] = [:]
        for (key, value) in self {
            guard let key = key as? String else { continue }
            result[key] = (value as? String) ?? String(describing: value)
        }
        return result
    }
}
