//
//  KitoNotificationPreferences.swift
//  KitoNotifications
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI

/// A daily window when notifications stay quiet. It may run past midnight (22:00 – 07:00).
public struct KitoQuietHours: Equatable, Codable, Sendable {
    /// A time of day.
    public struct Time: Equatable, Comparable, Codable, Sendable {
        public var hour: Int
        public var minute: Int

        public init(hour: Int, minute: Int = 0) {
            self.hour = min(max(hour, 0), 23)
            self.minute = min(max(minute, 0), 59)
        }

        public var minutesSinceMidnight: Int { hour * 60 + minute }

        /// "22:00".
        public var label: String { String(format: "%02d:%02d", hour, minute) }

        public init(_ date: Date, calendar: Calendar = .current) {
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            self.init(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
        }

        /// Today (or `day`) at this time.
        public func date(on day: Date = Date(), calendar: Calendar = .current) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }

        public static func < (lhs: Time, rhs: Time) -> Bool { lhs.minutesSinceMidnight < rhs.minutesSinceMidnight }
    }

    public var isEnabled: Bool
    public var start: Time
    public var end: Time

    public init(isEnabled: Bool = true, start: Time = Time(hour: 22), end: Time = Time(hour: 7)) {
        self.isEnabled = isEnabled
        self.start = start
        self.end = end
    }

    /// Whether the window runs past midnight.
    public var crossesMidnight: Bool { end < start }

    /// Its length in minutes (0 when start equals end, which means never quiet).
    public var durationMinutes: Int {
        let difference = end.minutesSinceMidnight - start.minutesSinceMidnight
        return difference >= 0 ? difference : difference + 24 * 60
    }

    /// Whether `date` falls inside the window. Start is inside, end is not.
    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled, start != end else { return false }
        let minute = Time(date, calendar: calendar).minutesSinceMidnight
        if crossesMidnight {
            return minute >= start.minutesSinceMidnight || minute < end.minutesSinceMidnight
        }
        return minute >= start.minutesSinceMidnight && minute < end.minutesSinceMidnight
    }

    /// When the current quiet stretch ends, if `date` is inside one.
    public func end(after date: Date, calendar: Calendar = .current) -> Date? {
        guard contains(date, calendar: calendar) else { return nil }
        let todayEnd = end.date(on: date, calendar: calendar)
        if todayEnd > date { return todayEnd }
        return calendar.date(byAdding: .day, value: 1, to: todayEnd)
    }

    /// "Quiet until 07:00" or "22:00 – 07:00".
    public func summary(at date: Date = Date(), calendar: Calendar = .current) -> String {
        guard isEnabled else { return "Off" }
        if contains(date, calendar: calendar) { return "Quiet until \(end.label)" }
        return "\(start.label) – \(end.label)"
    }
}

/// A kind of notification people can turn on or off — usually one per category id.
public struct KitoNotificationChannel: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var systemImage: String
    public var tint: Color
    public var isOn: Bool

    public init(_ id: String, title: String, subtitle: String, systemImage: String, tint: Color, isOn: Bool = true) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tint = tint
        self.isOn = isOn
    }

    /// A channel for one of the standard kinds, identified by the kind's raw value.
    public init(_ kind: KitoNotificationKind, subtitle: String, isOn: Bool = true) {
        self.init(kind.rawValue, title: kind.displayName, subtitle: subtitle, systemImage: kind.systemImage, tint: kind.tint, isOn: isOn)
    }
}

/// What someone wants to hear about, and when.
public struct KitoNotificationPreferences: Equatable, Sendable {
    public enum Previews: String, CaseIterable, Sendable {
        case always = "Always"
        case whenUnlocked = "When unlocked"
        case never = "Never"
    }

    public var channels: [KitoNotificationChannel]
    public var quietHours: KitoQuietHours
    /// Time-sensitive notifications still come through during quiet hours.
    public var allowsTimeSensitive: Bool
    public var previews: Previews
    public var playsSounds: Bool
    public var showsBadges: Bool

    public init(
        channels: [KitoNotificationChannel],
        quietHours: KitoQuietHours = KitoQuietHours(isEnabled: false),
        allowsTimeSensitive: Bool = true,
        previews: Previews = .always,
        playsSounds: Bool = true,
        showsBadges: Bool = true
    ) {
        self.channels = channels
        self.quietHours = quietHours
        self.allowsTimeSensitive = allowsTimeSensitive
        self.previews = previews
        self.playsSounds = playsSounds
        self.showsBadges = showsBadges
    }

    /// Orders, payments, messages and reminders on; offers off; quiet hours 22:00 – 07:00.
    public static let standard = KitoNotificationPreferences(
        channels: [
            KitoNotificationChannel(.order, subtitle: "Confirmed, on the way, delivered"),
            KitoNotificationChannel(.payment, subtitle: "Money in and out, receipts"),
            KitoNotificationChannel(.message, subtitle: "Replies and mentions"),
            KitoNotificationChannel(.reminder, subtitle: "Bills and bookings you set"),
            KitoNotificationChannel(.security, subtitle: "New sign-ins and password changes"),
            KitoNotificationChannel(.promo, subtitle: "Deals picked for you", isOn: false),
        ],
        quietHours: KitoQuietHours()
    )

    /// Whether a notification on `channelID` should make itself heard at `date`: its channel
    /// is on (unknown channels count as on) and it isn't quiet hours — unless it's time
    /// sensitive and those are allowed through.
    public func allows(channelID: String?, at date: Date = Date(), isTimeSensitive: Bool = false, calendar: Calendar = .current) -> Bool {
        if let channelID, let channel = channels.first(where: { $0.id == channelID }), !channel.isOn { return false }
        if quietHours.contains(date, calendar: calendar) && !(isTimeSensitive && allowsTimeSensitive) { return false }
        return true
    }

    /// How many channels are on.
    public var enabledCount: Int { channels.filter(\.isOn).count }
}
