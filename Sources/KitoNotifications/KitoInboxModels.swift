//
//  KitoInboxModels.swift
//  KitoNotifications
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI

/// What a notification is about — sets its icon badge and colour.
public enum KitoNotificationKind: String, CaseIterable, Codable, Sendable {
    case message, order, payment, social, reminder, security, promo, system

    public var displayName: String {
        switch self {
        case .message: return "Messages"
        case .order: return "Orders"
        case .payment: return "Payments"
        case .social: return "Social"
        case .reminder: return "Reminders"
        case .security: return "Security"
        case .promo: return "Offers"
        case .system: return "Updates"
        }
    }

    public var systemImage: String {
        switch self {
        case .message: return "bubble.left.fill"
        case .order: return "shippingbox.fill"
        case .payment: return "creditcard.fill"
        case .social: return "heart.fill"
        case .reminder: return "alarm.fill"
        case .security: return "lock.shield.fill"
        case .promo: return "tag.fill"
        case .system: return "sparkles"
        }
    }

    public var tint: Color {
        switch self {
        case .message: return Color(red: 0.13, green: 0.55, blue: 0.98)
        case .order: return Color(red: 0.98, green: 0.55, blue: 0.10)
        case .payment: return Color(red: 0.12, green: 0.68, blue: 0.42)
        case .social: return Color(red: 0.96, green: 0.27, blue: 0.47)
        case .reminder: return Color(red: 0.58, green: 0.36, blue: 0.96)
        case .security: return Color(red: 0.90, green: 0.25, blue: 0.25)
        case .promo: return Color(red: 0.95, green: 0.72, blue: 0.10)
        case .system: return Color(red: 0.35, green: 0.40, blue: 0.50)
        }
    }
}

/// The picture on a notification row.
public enum KitoNotificationAvatar: Hashable, Sendable {
    /// A person's initials on a colour.
    case initials(String, Color)
    /// A symbol on a colour — for brands and system events.
    case symbol(String, Color)
    /// A remote photo.
    case image(URL)
}

/// One notification in the in-app inbox.
public struct KitoInboxNotification: Identifiable, Hashable, Sendable {
    public var id: String
    public var kind: KitoNotificationKind
    public var title: String
    public var body: String
    public var date: Date
    public var isRead: Bool
    public var avatar: KitoNotificationAvatar?
    /// An inline button: "Track", "Reply", "View receipt".
    public var actionTitle: String?

    public init(
        id: String = UUID().uuidString,
        kind: KitoNotificationKind,
        title: String,
        body: String,
        date: Date = Date(),
        isRead: Bool = false,
        avatar: KitoNotificationAvatar? = nil,
        actionTitle: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.date = date
        self.isRead = isRead
        self.avatar = avatar
        self.actionTitle = actionTitle
    }

    /// An inbox entry for a notification that arrived while the app was open. The kind comes
    /// from `userInfo["kind"]`, then the category id, else `.system`.
    public init(_ event: KitoNotificationEvent) {
        let kind = KitoNotificationKind(rawValue: event.userInfo["kind"] ?? "") ?? KitoNotificationKind(rawValue: event.categoryID) ?? .system
        self.init(id: event.notificationID, kind: kind, title: event.title, body: event.body, date: event.date, avatar: .symbol(kind.systemImage, kind.tint))
    }
}

/// A heading in the inbox.
public enum KitoInboxGroup: String, CaseIterable, Sendable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This week"
    case earlier = "Earlier"
}

/// How the inbox splits notifications into sections.
public enum KitoInboxGrouping: Sendable {
    /// Today and Earlier.
    case todayAndEarlier
    /// Today, Yesterday, This week and Earlier.
    case byDay
}

/// Which notifications the inbox shows.
public enum KitoInboxFilter: Hashable, Sendable {
    case all
    case unread
    case kind(KitoNotificationKind)
}

/// A section of the inbox.
public struct KitoInboxSection: Identifiable, Equatable, Sendable {
    public var group: KitoInboxGroup
    public var items: [KitoInboxNotification]
    public var id: String { group.rawValue }
}

/// The inbox's pure logic: grouping, filtering, counting and short relative times.
public enum KitoInbox {
    /// Newest first, split into sections; empty sections are left out.
    public static func sections(
        _ items: [KitoInboxNotification],
        grouping: KitoInboxGrouping = .todayAndEarlier,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [KitoInboxSection] {
        let sorted = items.sorted { $0.date > $1.date }
        var buckets: [KitoInboxGroup: [KitoInboxNotification]] = [:]
        for item in sorted {
            buckets[group(for: item.date, grouping: grouping, now: now, calendar: calendar), default: []].append(item)
        }
        return KitoInboxGroup.allCases.compactMap { group in
            guard let items = buckets[group], !items.isEmpty else { return nil }
            return KitoInboxSection(group: group, items: items)
        }
    }

    /// The section a date falls into.
    public static func group(for date: Date, grouping: KitoInboxGrouping, now: Date = Date(), calendar: Calendar = .current) -> KitoInboxGroup {
        if calendar.isDate(date, inSameDayAs: now) { return .today }
        guard grouping == .byDay else { return .earlier }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) { return .yesterday }
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)), date >= weekAgo { return .thisWeek }
        return .earlier
    }

    public static func filter(_ items: [KitoInboxNotification], by filter: KitoInboxFilter) -> [KitoInboxNotification] {
        switch filter {
        case .all: return items
        case .unread: return items.filter { !$0.isRead }
        case .kind(let kind): return items.filter { $0.kind == kind }
        }
    }

    public static func unreadCount(_ items: [KitoInboxNotification], kind: KitoNotificationKind? = nil) -> Int {
        items.filter { !$0.isRead && (kind == nil || $0.kind == kind) }.count
    }

    /// The kinds present, in a stable order — for filter chips.
    public static func kinds(in items: [KitoInboxNotification]) -> [KitoNotificationKind] {
        KitoNotificationKind.allCases.filter { kind in items.contains { $0.kind == kind } }
    }

    /// "now", "5m", "3h", "Yesterday", "Mon", "12 Sep".
    public static func relativeTime(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "now" }
        if seconds < 3_600 { return "\(Int(seconds / 60))m" }
        if calendar.isDate(date, inSameDayAs: now) { return "\(Int(seconds / 3_600))h" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday" }
        if seconds < 7 * 86_400 {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
