//
//  KitoNotificationInboxAPITests.swift
//  KitoNotifications
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
import SwiftUI
@testable import KitoNotifications

@MainActor
final class KitoNotificationInboxAPITests: XCTestCase {
    private let item = KitoInboxNotification(id: "a", kind: .order, title: "Order", body: "", date: Date())

    func testTrailingClosureIsOnOpen() {
        var opened: [String] = []
        let inbox = KitoNotificationInbox(.constant([item])) { opened.append($0.id) }
        inbox.onOpen?(item)
        XCTAssertEqual(opened, ["a"])
        XCTAssertNil(inbox.onAction)
    }

    func testActionBeforeTrailingOpen() {
        var opened = 0, acted = 0
        let inbox = KitoNotificationInbox(.constant([item]), onAction: { _ in acted += 1 }) { _ in opened += 1 }
        inbox.onOpen?(item)
        inbox.onAction?(item)
        XCTAssertEqual(opened, 1)
        XCTAssertEqual(acted, 1)
    }

    func testOriginalLabelledOrderStillWorks() {
        var opened = 0, acted = 0
        let inbox = KitoNotificationInbox(.constant([item]), onOpen: { _ in opened += 1 }, onAction: { _ in acted += 1 })
        inbox.onOpen?(item)
        inbox.onAction?(item)
        XCTAssertEqual(opened, 1)
        XCTAssertEqual(acted, 1)

        let actionOnly = KitoNotificationInbox(.constant([item]), onAction: { _ in acted += 1 })
        XCTAssertNil(actionOnly.onOpen)
        XCTAssertNotNil(actionOnly.onAction)
        XCTAssertNil(KitoNotificationInbox(.constant([])).onOpen)
    }

    func testRenamedTypes() {
        let setting = KitoNotificationChannelSetting(.order, subtitle: "Orders")
        XCTAssertEqual(setting.id, KitoNotificationKind.order.rawValue)
        _ = KitoNotificationQuietHoursDial(quietHours: KitoQuietHours())
    }
}
