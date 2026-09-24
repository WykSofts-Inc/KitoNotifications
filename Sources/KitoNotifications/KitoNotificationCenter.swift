//
//  KitoNotificationCenter.swift
//  KitoNotifications
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import Observation
import UserNotifications

/// Local notifications in one observable place: permission (including provisional), scheduling,
/// categories with actions, the badge, pending and delivered lists — and a delegate that shows
/// banners, sound and badge **while the app is open** and routes taps and actions to your code.
///
/// Without a delegate iOS silently drops notifications that arrive in the foreground, so install
/// it as early as possible — before the first scene appears:
///
/// ```swift
/// init() { KitoNotificationCenter.shared.install() }
/// ```
///
/// `install()` replaces any delegate already set. If your app has its own, keep it and forward:
/// return `presentationOptions(for:)` from `willPresent` and call `handle(_:)` from `didReceive`.
@MainActor
@Observable
public final class KitoNotificationCenter {
    public static let shared = KitoNotificationCenter()

    public private(set) var authorization: KitoNotificationAuthorization = .notDetermined
    public private(set) var pending: [KitoScheduledNotification] = []
    public private(set) var delivered: [KitoScheduledNotification] = []
    public private(set) var badgeCount = 0
    /// The latest notification that arrived while the app was open.
    public private(set) var lastForegroundEvent: KitoNotificationEvent?
    /// The latest tap or action.
    public private(set) var lastResponse: KitoNotificationResponse?
    public private(set) var isInstalled = false

    /// What a notification that arrives in the foreground shows. Defaults to banner, list,
    /// sound and badge — the same as when the app is closed.
    public var foregroundPresentation: UNNotificationPresentationOptions = [.banner, .list, .sound, .badge] {
        didSet { delegate.setOptions(foregroundPresentation) }
    }

    /// When set, foreground notifications respect these channels and quiet hours (a channel
    /// is matched by the notification's category id).
    public var preferences: KitoNotificationPreferences? {
        didSet { delegate.setPreferences(preferences) }
    }

    @ObservationIgnored private let delegate = KitoNotificationDelegate()
    @ObservationIgnored private var tapHandlers: [(KitoNotificationResponse) -> Void] = []
    @ObservationIgnored private var actionHandlers: [String: (KitoNotificationResponse) -> Void] = [:]
    @ObservationIgnored private var foregroundHandlers: [(KitoNotificationEvent) -> Void] = []

    private var system: UNUserNotificationCenter { .current() }

    public init() {
        delegate.setOptions(foregroundPresentation)
        delegate.owner = self
    }

    // MARK: Delegate

    /// Makes this centre the system notification delegate, so notifications show while the app
    /// is open and taps reach your handlers. Safe to call more than once.
    public func install() {
        system.delegate = delegate
        isInstalled = true
    }

    /// The options to return from your own `willPresent`, if you keep your own delegate.
    public func presentationOptions(for notification: UNNotification) -> UNNotificationPresentationOptions {
        delegate.options(for: notification.request.content.categoryIdentifier, interruption: notification.request.content.interruptionLevel)
    }

    /// Routes a response from your own `didReceive`, if you keep your own delegate.
    public func handle(_ response: UNNotificationResponse) {
        route(KitoNotificationDelegate.makeResponse(response))
    }

    // MARK: Handlers

    /// Called when a notification itself is tapped.
    public func onTap(_ handler: @escaping (KitoNotificationResponse) -> Void) {
        tapHandlers.append(handler)
    }

    /// Called when the action with `id` is chosen (including reply actions — read `text`).
    public func onAction(_ id: String, _ handler: @escaping (KitoNotificationResponse) -> Void) {
        actionHandlers[id] = handler
    }

    /// Called when a notification arrives while the app is open.
    public func onForeground(_ handler: @escaping (KitoNotificationEvent) -> Void) {
        foregroundHandlers.append(handler)
    }

    func route(_ response: KitoNotificationResponse) {
        lastResponse = response
        if let actionID = response.actionID {
            actionHandlers[actionID]?(response)
        } else if !response.isDismissal {
            tapHandlers.forEach { $0(response) }
        }
    }

    func receiveForeground(_ event: KitoNotificationEvent) {
        lastForegroundEvent = event
        foregroundHandlers.forEach { $0(event) }
    }

    // MARK: Authorization

    public func refreshAuthorization() async {
        let settings = await system.notificationSettings()
        authorization = KitoNotificationAuthorization(settings.authorizationStatus)
    }

    /// Asks for alerts, sounds and badges. `provisional` skips the prompt and delivers quietly
    /// to Notification Centre until the person chooses — a gentle way to earn the full yes.
    @discardableResult
    public func requestAuthorization(provisional: Bool = false) async -> KitoNotificationAuthorization {
        var options: UNAuthorizationOptions = [.alert, .sound, .badge]
        if provisional { options.insert(.provisional) }
        _ = try? await system.requestAuthorization(options: options)
        await refreshAuthorization()
        return authorization
    }

    // MARK: Scheduling

    /// Registers the action sets notifications can use through `categoryID`.
    public func setCategories(_ categories: [KitoNotificationCategory]) {
        system.setNotificationCategories(Set(categories.map { $0.makeCategory() }))
    }

    /// Schedules (or replaces, by id) a local notification.
    public func schedule(_ notification: KitoLocalNotification) async throws {
        try await system.add(notification.makeRequest())
        await refresh()
    }

    public func cancel(_ ids: [String]) async {
        system.removePendingNotificationRequests(withIdentifiers: ids)
        await refresh()
    }

    public func cancelAll() async {
        system.removeAllPendingNotificationRequests()
        await refresh()
    }

    public func removeDelivered(_ ids: [String]) async {
        system.removeDeliveredNotifications(withIdentifiers: ids)
        await refresh()
    }

    public func removeAllDelivered() async {
        system.removeAllDeliveredNotifications()
        await refresh()
    }

    /// Re-reads the pending and delivered lists.
    public func refresh() async {
        let requests = await system.pendingNotificationRequests()
        let notifications = await system.deliveredNotifications()
        pending = requests.map { request in
            var next: Date?
            var repeats = false
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                next = trigger.nextTriggerDate()
                repeats = trigger.repeats
            } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                next = trigger.nextTriggerDate()
                repeats = trigger.repeats
            }
            return KitoScheduledNotification(id: request.identifier, title: request.content.title, body: request.content.body, categoryID: request.content.categoryIdentifier, nextFireDate: next, repeats: repeats)
        }
        .sorted { ($0.nextFireDate ?? .distantFuture) < ($1.nextFireDate ?? .distantFuture) }
        delivered = notifications.map { notification in
            let content = notification.request.content
            return KitoScheduledNotification(id: notification.request.identifier, title: content.title, body: content.body, categoryID: content.categoryIdentifier, deliveredAt: notification.date)
        }
        .sorted { ($0.deliveredAt ?? .distantPast) > ($1.deliveredAt ?? .distantPast) }
    }

    // MARK: Badge

    public func setBadge(_ count: Int) async {
        let value = max(count, 0)
        try? await system.setBadgeCount(value)
        badgeCount = value
    }

    public func clearBadge() async {
        await setBadge(0)
    }
}

/// The system delegate. Kept separate from the observable centre because the system may call it
/// off the main thread; everything it hands on hops to the main actor.
final class KitoNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    weak var owner: KitoNotificationCenter?
    private let lock = NSLock()
    private var presentation: UNNotificationPresentationOptions = [.banner, .list, .sound, .badge]
    private var preferences: KitoNotificationPreferences?

    func setOptions(_ options: UNNotificationPresentationOptions) {
        lock.withLock { presentation = options }
    }

    func setPreferences(_ preferences: KitoNotificationPreferences?) {
        lock.withLock { self.preferences = preferences }
    }

    func options(for categoryID: String, interruption: UNNotificationInterruptionLevel, at date: Date = Date()) -> UNNotificationPresentationOptions {
        let (options, preferences) = lock.withLock { (presentation, self.preferences) }
        guard let preferences else { return options }
        let allowed = preferences.allows(channelID: categoryID.isEmpty ? nil : categoryID, at: date, isTimeSensitive: interruption == .timeSensitive || interruption == .critical)
        // Quiet: still land in Notification Centre, just without the banner and sound.
        return allowed ? options : options.intersection([.list, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        let event = KitoNotificationEvent(
            notificationID: notification.request.identifier,
            title: content.title,
            subtitle: content.subtitle,
            body: content.body,
            categoryID: content.categoryIdentifier,
            threadID: content.threadIdentifier,
            userInfo: content.userInfo.kitoStrings,
            date: notification.date
        )
        completionHandler(options(for: content.categoryIdentifier, interruption: content.interruptionLevel))
        Task { @MainActor [weak self] in self?.owner?.receiveForeground(event) }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let routed = Self.makeResponse(response)
        Task { @MainActor [weak self] in self?.owner?.route(routed) }
        completionHandler()
    }

    static func makeResponse(_ response: UNNotificationResponse) -> KitoNotificationResponse {
        let content = response.notification.request.content
        let action = response.actionIdentifier
        let isTap = action == UNNotificationDefaultActionIdentifier
        let isDismiss = action == UNNotificationDismissActionIdentifier
        return KitoNotificationResponse(
            notificationID: response.notification.request.identifier,
            categoryID: content.categoryIdentifier,
            actionID: isTap || isDismiss ? nil : action,
            title: content.title,
            body: content.body,
            userInfo: content.userInfo.kitoStrings,
            text: (response as? UNTextInputNotificationResponse)?.userText,
            isDismissal: isDismiss
        )
    }
}
