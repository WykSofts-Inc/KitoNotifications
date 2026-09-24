//
//  KitoNotificationRow.swift
//  KitoNotifications
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// An avatar (initials, a symbol tile or a photo) with the notification kind badged in the corner.
public struct KitoNotificationAvatarView: View {
    @Environment(\.kitoTheme) private var theme
    let avatar: KitoNotificationAvatar?
    let kind: KitoNotificationKind
    let size: CGFloat
    let showsBadge: Bool

    public init(_ avatar: KitoNotificationAvatar?, kind: KitoNotificationKind, size: CGFloat = 46, showsBadge: Bool = true) {
        self.avatar = avatar
        self.kind = kind
        self.size = size
        self.showsBadge = showsBadge
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            face
                .frame(width: size, height: size)
            if showsBadge, !isKindTile {
                Image(systemName: kind.systemImage)
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size * 0.42, height: size * 0.42)
                    .background(Circle().fill(kind.tint))
                    .overlay(Circle().stroke(theme.colors.surface, lineWidth: 2))
                    .offset(x: 3, y: 3)
            }
        }
        .accessibilityHidden(true)
    }

    private var isKindTile: Bool {
        if case .symbol = avatar ?? .symbol(kind.systemImage, kind.tint) { return true }
        return false
    }

    @ViewBuilder
    private var face: some View {
        switch avatar ?? .symbol(kind.systemImage, kind.tint) {
        case .initials(let initials, let color):
            Circle()
                .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Text(initials).font(.system(size: size * 0.36, weight: .semibold, design: .rounded)).foregroundStyle(.white))
        case .symbol(let symbol, let color):
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Image(systemName: symbol).font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(.white))
        case .image(let url):
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Circle().fill(kind.tint.opacity(0.2))
                }
            }
            .clipShape(Circle())
        }
    }
}

/// One inbox row: avatar, bold title while unread, two lines of body, a short relative time,
/// an unread dot and an optional inline action.
public struct KitoNotificationRow: View {
    @Environment(\.kitoTheme) private var theme
    let item: KitoInboxNotification
    let now: Date
    let onAction: (() -> Void)?

    public init(_ item: KitoInboxNotification, now: Date = Date(), onAction: (() -> Void)? = nil) {
        self.item = item
        self.now = now
        self.onAction = onAction
    }

    public var body: some View {
        HStack(alignment: .top, spacing: theme.spacing.md) {
            KitoNotificationAvatarView(item.avatar, kind: item.kind)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: theme.spacing.xs) {
                    Text(item.title)
                        .font(.system(size: 15, weight: item.isRead ? .medium : .semibold))
                        .foregroundStyle(theme.colors.onSurface)
                        .lineLimit(1)
                    Spacer(minLength: theme.spacing.xs)
                    Text(KitoInbox.relativeTime(item.date, now: now))
                        .font(.system(size: 12, weight: item.isRead ? .regular : .semibold))
                        .foregroundStyle(item.isRead ? theme.colors.onSurface.opacity(0.45) : theme.colors.primary)
                }
                Text(item.body)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.colors.onSurface.opacity(item.isRead ? 0.55 : 0.75))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle = item.actionTitle {
                    Button(actionTitle) { onAction?() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.colors.onSurface)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 30)
                        .background(Capsule().strokeBorder(theme.colors.onSurface.opacity(0.18), lineWidth: 1))
                        .buttonStyle(.borderless)
                        .padding(.top, 4)
                }
            }
            Circle()
                .fill(theme.colors.primary)
                .frame(width: 9, height: 9)
                .padding(.top, 20)
                .opacity(item.isRead ? 0 : 1)
                .scaleEffect(item.isRead ? 0.3 : 1)
        }
        .padding(.vertical, theme.spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.isRead ? "" : "Unread. ")\(item.title). \(item.body). \(KitoInbox.relativeTime(item.date, now: now))")
    }
}
