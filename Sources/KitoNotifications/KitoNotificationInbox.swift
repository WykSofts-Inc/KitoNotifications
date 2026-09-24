//
//  KitoNotificationInbox.swift
//  KitoNotifications
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// An in-app notification centre: a header with the unread count and Mark all read, filter
/// chips (All, Unread, and one per kind present), Today / Earlier sections, unread dots, swipe
/// right to toggle read and left to delete, and a friendly "all caught up" state.
public struct KitoNotificationInbox: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var items: [KitoInboxNotification]
    let title: String
    let grouping: KitoInboxGrouping
    let showsFilters: Bool
    let onOpen: ((KitoInboxNotification) -> Void)?
    let onAction: ((KitoInboxNotification) -> Void)?

    @State private var filter: KitoInboxFilter = .all

    public init(
        _ items: Binding<[KitoInboxNotification]>,
        title: String = "Notifications",
        grouping: KitoInboxGrouping = .todayAndEarlier,
        showsFilters: Bool = true,
        onOpen: ((KitoInboxNotification) -> Void)? = nil,
        onAction: ((KitoInboxNotification) -> Void)? = nil
    ) {
        self._items = items
        self.title = title
        self.grouping = grouping
        self.showsFilters = showsFilters
        self.onOpen = onOpen
        self.onAction = onAction
    }

    private var animation: Animation? { reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85) }
    private var unread: Int { KitoInbox.unreadCount(items) }
    private var sections: [KitoInboxSection] { KitoInbox.sections(KitoInbox.filter(items, by: filter), grouping: grouping) }

    public var body: some View {
        List {
            header
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
            if showsFilters && !items.isEmpty {
                chips
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
            }
            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        KitoNotificationRow(item, onAction: { onAction?(item) })
                            .listRowBackground(item.isRead ? Color.clear : theme.colors.primary.opacity(0.05))
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .onTapGesture { open(item) }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { toggleRead(item) } label: {
                                    Label(item.isRead ? "Unread" : "Read", systemImage: item.isRead ? "envelope.badge.fill" : "envelope.open.fill")
                                }
                                .tint(theme.colors.primary)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { delete(item) } label: { Label("Delete", systemImage: "trash.fill") }
                            }
                            .accessibilityAction(named: item.isRead ? "Mark as unread" : "Mark as read") { toggleRead(item) }
                            .accessibilityAction(named: "Delete") { delete(item) }
                    }
                } header: {
                    HStack {
                        Text(section.group.rawValue)
                            .font(.system(size: 13, weight: .bold))
                            .textCase(.uppercase)
                            .kerning(0.6)
                            .foregroundStyle(theme.colors.onSurface.opacity(0.5))
                        Spacer()
                        let count = KitoInbox.unreadCount(section.items)
                        if count > 0 {
                            Text("\(count) new")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(theme.colors.primary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.colors.surface)
        .overlay {
            if sections.isEmpty {
                KitoInboxEmptyState(isFiltered: !items.isEmpty) { withAnimation(animation) { filter = .all } }
                    .padding(.top, 120)
                    .transition(.opacity)
            }
        }
        .animation(animation, value: items)
        .animation(animation, value: filter)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.typography.displayMedium.weight(.bold))
                    .foregroundStyle(theme.colors.onSurface)
                Text(unread == 0 ? "You're all caught up" : "\(unread) unread")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.55))
                    .contentTransition(.numericText())
            }
            Spacer()
            if unread > 0 {
                Button("Mark all read") {
                    withAnimation(animation) { for index in items.indices { items[index].isRead = true } }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.colors.primary)
                .buttonStyle(.borderless)
            }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", count: nil, filter: .all)
                chip("Unread", count: unread, filter: .unread)
                ForEach(KitoInbox.kinds(in: items), id: \.self) { kind in
                    chip(kind.displayName, count: nil, filter: .kind(kind), symbol: kind.systemImage)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(_ label: String, count: Int?, filter value: KitoInboxFilter, symbol: String? = nil) -> some View {
        let isOn = filter == value
        return Button { withAnimation(animation) { filter = value } } label: {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .bold)) }
                Text(label)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(isOn ? theme.colors.surface.opacity(0.25) : theme.colors.primary))
                        .foregroundStyle(isOn ? theme.colors.surface : theme.colors.onPrimary)
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(Capsule().fill(isOn ? theme.colors.onSurface : theme.colors.onSurface.opacity(0.07)))
            .foregroundStyle(isOn ? theme.colors.surface : theme.colors.onSurface)
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func open(_ item: KitoInboxNotification) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            withAnimation(animation) { items[index].isRead = true }
        }
        onOpen?(item)
    }

    private func toggleRead(_ item: KitoInboxNotification) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(animation) { items[index].isRead.toggle() }
    }

    private func delete(_ item: KitoInboxNotification) {
        withAnimation(animation) { items.removeAll { $0.id == item.id } }
    }
}

/// A sleeping bell, for an empty inbox (or an empty filter).
public struct KitoInboxEmptyState: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isFiltered: Bool
    let onClearFilter: () -> Void
    @State private var float = false

    public init(isFiltered: Bool = false, onClearFilter: @escaping () -> Void = {}) {
        self.isFiltered = isFiltered
        self.onClearFilter = onClearFilter
    }

    public var body: some View {
        VStack(spacing: theme.spacing.md) {
            ZStack {
                Circle().fill(theme.colors.primary.opacity(0.08)).frame(width: 130, height: 130)
                Circle().fill(theme.colors.primary.opacity(0.08)).frame(width: 92, height: 92)
                Image(systemName: isFiltered ? "line.3.horizontal.decrease.circle" : "bell.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(theme.colors.primary)
                    .rotationEffect(.degrees(float && !isFiltered ? -8 : 8), anchor: .top)
                if !isFiltered {
                    Text("z").font(.system(size: 16, weight: .bold, design: .rounded)).offset(x: 34, y: float ? -40 : -30).opacity(float ? 0.3 : 0.9)
                    Text("z").font(.system(size: 12, weight: .bold, design: .rounded)).offset(x: 48, y: float ? -56 : -48).opacity(float ? 0.9 : 0.3)
                }
            }
            .foregroundStyle(theme.colors.primary)
            .accessibilityHidden(true)
            Text(isFiltered ? "Nothing here" : "You're all caught up")
                .font(theme.typography.titleMedium)
                .foregroundStyle(theme.colors.onSurface)
            Text(isFiltered ? "No notifications match this filter." : "New orders, payments and messages will show up here.")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.onSurface.opacity(0.55))
                .multilineTextAlignment(.center)
            if isFiltered {
                Button("Show all", action: onClearFilter)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.colors.surface)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(theme.colors.onSurface))
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, theme.spacing.xl)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { float = true }
        }
    }
}
