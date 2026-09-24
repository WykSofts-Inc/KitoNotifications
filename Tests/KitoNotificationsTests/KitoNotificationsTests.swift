//
//  KitoNotificationsTests.swift
//  KitoNotifications
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
import UserNotifications
@testable import KitoNotifications

private let nairobi: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Africa/Nairobi")!
    return calendar
}()

private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    nairobi.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
}

final class KitoInboxGroupingTests: XCTestCase {
    private let now = date(24, 15)

    private func item(_ id: String, _ date: Date, read: Bool = false, kind: KitoNotificationKind = .order) -> KitoInboxNotification {
        KitoInboxNotification(id: id, kind: kind, title: id, body: "", date: date, isRead: read)
    }

    func testTodayAndEarlier() {
        let items = [item("old", date(20, 9)), item("morning", date(24, 8)), item("afternoon", date(24, 14)), item("yesterday", date(23, 22))]
        let sections = KitoInbox.sections(items, grouping: .todayAndEarlier, now: now, calendar: nairobi)
        XCTAssertEqual(sections.map(\.group), [.today, .earlier])
        XCTAssertEqual(sections[0].items.map(\.id), ["afternoon", "morning"], "newest first")
        XCTAssertEqual(sections[1].items.map(\.id), ["yesterday", "old"])
    }

    func testByDay() {
        let items = [item("today", date(24, 9)), item("yesterday", date(23, 9)), item("week", date(19, 9)), item("month", date(2, 9))]
        let sections = KitoInbox.sections(items, grouping: .byDay, now: now, calendar: nairobi)
        XCTAssertEqual(sections.map(\.group), [.today, .yesterday, .thisWeek, .earlier])
    }

    func testEmptySectionsAreDropped() {
        XCTAssertTrue(KitoInbox.sections([], now: now, calendar: nairobi).isEmpty)
        let sections = KitoInbox.sections([item("a", date(1, 9))], now: now, calendar: nairobi)
        XCTAssertEqual(sections.map(\.group), [.earlier])
    }

    func testUnreadCountsAndFilters() {
        let items = [item("a", now), item("b", now, read: true), item("c", now, kind: .payment), item("d", now, read: true, kind: .payment)]
        XCTAssertEqual(KitoInbox.unreadCount(items), 2)
        XCTAssertEqual(KitoInbox.unreadCount(items, kind: .payment), 1)
        XCTAssertEqual(KitoInbox.filter(items, by: .unread).map(\.id), ["a", "c"])
        XCTAssertEqual(KitoInbox.filter(items, by: .kind(.payment)).map(\.id), ["c", "d"])
        XCTAssertEqual(KitoInbox.filter(items, by: .all).count, 4)
        XCTAssertEqual(KitoInbox.kinds(in: items), [.order, .payment])
    }

    func testRelativeTime() {
        XCTAssertEqual(KitoInbox.relativeTime(now.addingTimeInterval(-20), now: now, calendar: nairobi), "now")
        XCTAssertEqual(KitoInbox.relativeTime(now.addingTimeInterval(-5 * 60), now: now, calendar: nairobi), "5m")
        XCTAssertEqual(KitoInbox.relativeTime(date(24, 12), now: now, calendar: nairobi), "3h")
        XCTAssertEqual(KitoInbox.relativeTime(date(23, 12), now: now, calendar: nairobi), "Yesterday")
        XCTAssertEqual(KitoInbox.relativeTime(date(1, 12), now: now, calendar: nairobi), "1 Sep")
    }

    func testForegroundEventBecomesInboxItem() {
        let event = KitoNotificationEvent(notificationID: "n1", title: "Paid", body: "KSh 500", categoryID: "payment")
        XCTAssertEqual(KitoInboxNotification(event).kind, .payment)
        let tagged = KitoNotificationEvent(notificationID: "n2", title: "Hi", body: "", categoryID: "chat", userInfo: ["kind": "message"])
        XCTAssertEqual(KitoInboxNotification(tagged).kind, .message)
        XCTAssertEqual(KitoInboxNotification(KitoNotificationEvent(notificationID: "n3", title: "", body: "")).kind, .system)
    }
}

final class KitoQuietHoursTests: XCTestCase {
    func testOvernightWindow() {
        let quiet = KitoQuietHours(start: .init(hour: 22), end: .init(hour: 7))
        XCTAssertTrue(quiet.crossesMidnight)
        XCTAssertTrue(quiet.contains(date(24, 23, 30), calendar: nairobi))
        XCTAssertTrue(quiet.contains(date(24, 2), calendar: nairobi))
        XCTAssertTrue(quiet.contains(date(24, 22), calendar: nairobi), "start is inside")
        XCTAssertFalse(quiet.contains(date(24, 7), calendar: nairobi), "end is outside")
        XCTAssertFalse(quiet.contains(date(24, 12), calendar: nairobi))
        XCTAssertEqual(quiet.durationMinutes, 9 * 60)
    }

    func testSameDayWindow() {
        let quiet = KitoQuietHours(start: .init(hour: 13), end: .init(hour: 14, minute: 30))
        XCTAssertFalse(quiet.crossesMidnight)
        XCTAssertTrue(quiet.contains(date(24, 14, 15), calendar: nairobi))
        XCTAssertFalse(quiet.contains(date(24, 14, 30), calendar: nairobi))
        XCTAssertFalse(quiet.contains(date(24, 12, 59), calendar: nairobi))
    }

    func testDisabledOrZeroLengthIsNeverQuiet() {
        XCTAssertFalse(KitoQuietHours(isEnabled: false).contains(date(24, 23), calendar: nairobi))
        XCTAssertFalse(KitoQuietHours(start: .init(hour: 9), end: .init(hour: 9)).contains(date(24, 9), calendar: nairobi))
    }

    func testEndAfter() {
        let quiet = KitoQuietHours(start: .init(hour: 22), end: .init(hour: 7))
        XCTAssertEqual(quiet.end(after: date(24, 23), calendar: nairobi), date(25, 7))
        XCTAssertEqual(quiet.end(after: date(24, 3), calendar: nairobi), date(24, 7))
        XCTAssertNil(quiet.end(after: date(24, 12), calendar: nairobi))
        XCTAssertEqual(quiet.summary(at: date(24, 23), calendar: nairobi), "Quiet until 07:00")
        XCTAssertEqual(quiet.summary(at: date(24, 12), calendar: nairobi), "22:00 – 07:00")
    }

    func testTimeClampsAndLabels() {
        XCTAssertEqual(KitoQuietHours.Time(hour: 27, minute: -3).label, "23:00")
        XCTAssertEqual(KitoQuietHours.Time(hour: 6, minute: 5).label, "06:05")
    }

    func testPreferencesRespectChannelsAndQuietHours() {
        var preferences = KitoNotificationPreferences.standard
        XCTAssertFalse(preferences.allows(channelID: "promo", at: date(24, 12), calendar: nairobi), "offers are off by default")
        XCTAssertTrue(preferences.allows(channelID: "order", at: date(24, 12), calendar: nairobi))
        XCTAssertTrue(preferences.allows(channelID: "unknown", at: date(24, 12), calendar: nairobi))
        XCTAssertFalse(preferences.allows(channelID: "order", at: date(24, 23), calendar: nairobi), "quiet hours")
        XCTAssertTrue(preferences.allows(channelID: "order", at: date(24, 23), isTimeSensitive: true, calendar: nairobi))
        preferences.allowsTimeSensitive = false
        XCTAssertFalse(preferences.allows(channelID: "order", at: date(24, 23), isTimeSensitive: true, calendar: nairobi))
        XCTAssertEqual(preferences.enabledCount, 5)
    }
}

final class KitoNotificationTriggerTests: XCTestCase {
    func testImmediateHasNoTrigger() {
        XCTAssertNil(KitoNotificationTrigger.immediately.makeTrigger())
        XCTAssertFalse(KitoNotificationTrigger.immediately.repeats)
    }

    func testTimeIntervals() throws {
        let once = try XCTUnwrap(KitoNotificationTrigger.after(0).makeTrigger() as? UNTimeIntervalNotificationTrigger)
        XCTAssertEqual(once.timeInterval, 1, "never zero, which the system rejects")
        XCTAssertFalse(once.repeats)

        let repeating = try XCTUnwrap(KitoNotificationTrigger.every(10).makeTrigger() as? UNTimeIntervalNotificationTrigger)
        XCTAssertEqual(repeating.timeInterval, 60, "repeating intervals are at least a minute")
        XCTAssertTrue(repeating.repeats)
    }

    func testCalendarTriggers() throws {
        let daily = try XCTUnwrap(KitoNotificationTrigger.daily(hour: 7, minute: 30).makeTrigger() as? UNCalendarNotificationTrigger)
        XCTAssertEqual(daily.dateComponents.hour, 7)
        XCTAssertEqual(daily.dateComponents.minute, 30)
        XCTAssertNil(daily.dateComponents.weekday)
        XCTAssertTrue(daily.repeats)

        let weekly = try XCTUnwrap(KitoNotificationTrigger.weekly(weekday: 9, hour: 25, minute: 0).makeTrigger() as? UNCalendarNotificationTrigger)
        XCTAssertEqual(weekly.dateComponents.weekday, 7, "clamped")
        XCTAssertEqual(weekly.dateComponents.hour, 23, "clamped")

        let at = try XCTUnwrap(KitoNotificationTrigger.at(date(30, 18, 45)).makeTrigger(calendar: nairobi) as? UNCalendarNotificationTrigger)
        XCTAssertEqual(at.dateComponents.day, 30)
        XCTAssertEqual(at.dateComponents.hour, 18)
        XCTAssertEqual(at.dateComponents.minute, 45)
        XCTAssertFalse(at.repeats)
    }

    func testSummaries() {
        XCTAssertEqual(KitoNotificationTrigger.after(300).summary, "In 5 min")
        XCTAssertEqual(KitoNotificationTrigger.daily(hour: 7, minute: 5).summary, "Daily at 07:05")
        XCTAssertEqual(KitoNotificationTrigger.weekly(weekday: 2, hour: 9, minute: 0).summary, "Mondays at 09:00")
        XCTAssertEqual(KitoNotificationTrigger.every(5_400).summary, "Every 1 h 30 min")
    }

    func testRequestCarriesContent() {
        let notification = KitoLocalNotification(id: "order-1", title: "Mama's Kitchen", subtitle: "Order #4821", body: "Your food is on the way", trigger: .after(5), categoryID: "order", threadID: "orders", badge: 2, userInfo: ["kind": "order"])
        let request = notification.makeRequest()
        XCTAssertEqual(request.identifier, "order-1")
        XCTAssertEqual(request.content.title, "Mama's Kitchen")
        XCTAssertEqual(request.content.categoryIdentifier, "order")
        XCTAssertEqual(request.content.threadIdentifier, "orders")
        XCTAssertEqual(request.content.badge, 2)
        XCTAssertEqual(request.content.userInfo["kind"] as? String, "order")
        XCTAssertNotNil(request.trigger)
    }

    func testCategoriesAndActions() {
        let category = KitoNotificationCategory("message", actions: [.reply(), KitoNotificationAction("mute", title: "Mute", isDestructive: true)])
        let system = category.makeCategory()
        XCTAssertEqual(system.identifier, "message")
        XCTAssertEqual(system.actions.count, 2)
        XCTAssertTrue(system.actions[0] is UNTextInputNotificationAction)
        XCTAssertTrue(system.actions[1].options.contains(.destructive))
    }

    func testAuthorizationMapping() {
        XCTAssertEqual(KitoNotificationAuthorization(.provisional), .provisional)
        XCTAssertTrue(KitoNotificationAuthorization.provisional.canNotify)
        XCTAssertFalse(KitoNotificationAuthorization.denied.canNotify)
    }

    func testQuietDelegateKeepsListButDropsBanner() {
        let delegate = KitoNotificationDelegate()
        delegate.setOptions([.banner, .list, .sound, .badge])
        XCTAssertEqual(delegate.options(for: "order", interruption: .active), [.banner, .list, .sound, .badge], "no preferences: everything")
        delegate.setPreferences(.standard)
        XCTAssertEqual(delegate.options(for: "promo", interruption: .active, at: date(24, 12)), [.list, .badge])
    }
}
