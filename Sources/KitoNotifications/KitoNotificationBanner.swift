//
//  KitoNotificationBanner.swift
//  KitoNotifications
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// How an in-app banner looks.
public enum KitoNotificationBannerStyle: String, CaseIterable, Sendable {
    /// Frosted, like the system's own banners.
    case system
    /// A solid card with a coloured edge and a glow in the kind's colour.
    case card
    /// A compact dark capsule that grows out of the top, like the Dynamic Island.
    case island
}

/// A banner for one notification.
public struct KitoNotificationBanner: View {
    @Environment(\.kitoTheme) private var theme
    let item: KitoInboxNotification
    let style: KitoNotificationBannerStyle
    let appName: String
    let progress: Double?

    public init(_ item: KitoInboxNotification, style: KitoNotificationBannerStyle = .system, appName: String? = nil, progress: Double? = nil) {
        self.item = item
        self.style = style
        self.appName = appName
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "App"
        self.progress = progress
    }

    public var body: some View {
        Group {
            switch style {
            case .system: system
            case .card: card
            case .island: island
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(appName) notification. \(item.title). \(item.body)")
        .accessibilityAddTraits(.isButton)
    }

    private var system: some View {
        HStack(alignment: .top, spacing: 12) {
            KitoNotificationAvatarView(item.avatar, kind: item.kind, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text("now").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Text(item.body).font(.system(size: 14)).foregroundStyle(Color.primary.opacity(0.8)).lineLimit(2)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .bottom) { progressLine.padding(.horizontal, 24).padding(.bottom, 5) }
        .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
    }

    private var card: some View {
        HStack(alignment: .top, spacing: 12) {
            KitoNotificationAvatarView(item.avatar, kind: item.kind, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: item.kind.systemImage).font(.system(size: 10, weight: .bold)).foregroundStyle(item.kind.tint)
                    Text(item.kind.displayName.uppercased()).font(.system(size: 11, weight: .bold)).kerning(0.6).foregroundStyle(item.kind.tint)
                    Spacer()
                    Text("now").font(.system(size: 12)).foregroundStyle(theme.colors.onSurface.opacity(0.45))
                }
                Text(item.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(theme.colors.onSurface).lineLimit(1)
                Text(item.body).font(.system(size: 14)).foregroundStyle(theme.colors.onSurface.opacity(0.7)).lineLimit(2)
                if let actionTitle = item.actionTitle {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.colors.surface)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 28)
                        .background(Capsule().fill(theme.colors.onSurface))
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.colors.surface)
                .shadow(color: item.kind.tint.opacity(0.35), radius: 24, y: 10)
        )
        .overlay(alignment: .leading) {
            Capsule().fill(item.kind.tint).frame(width: 4).padding(.vertical, 18).offset(x: 1)
        }
        .overlay(alignment: .bottom) { progressLine.padding(.horizontal, 22).padding(.bottom, 6) }
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(item.kind.tint.opacity(0.2), lineWidth: 1))
    }

    private var island: some View {
        HStack(spacing: 10) {
            KitoNotificationAvatarView(item.avatar, kind: item.kind, size: 34, showsBadge: false)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Text(item.body).font(.system(size: 12)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
            }
            Spacer(minLength: 6)
            Image(systemName: item.kind.systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(item.kind.tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(item.kind.tint.opacity(0.2)))
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black))
        .overlay(alignment: .bottom) { progressLine.padding(.horizontal, 30).padding(.bottom, 3) }
        .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var progressLine: some View {
        if let progress {
            GeometryReader { proxy in
                Capsule().fill(item.kind.tint.opacity(0.8))
                    .frame(width: proxy.size.width * max(0, min(progress, 1)), height: 2)
            }
            .frame(height: 2)
        }
    }
}

// MARK: - Presentation

private struct KitoNotificationBannerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var item: KitoInboxNotification?
    let style: KitoNotificationBannerStyle
    let duration: Duration
    let onTap: ((KitoInboxNotification) -> Void)?

    @State private var drag: CGFloat = 0
    @State private var progress: Double = 1
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            ZStack {
                if let current = item {
                    KitoNotificationBanner(current, style: style, progress: progress)
                        .padding(.horizontal, style == .island ? 28 : 12)
                        .padding(.top, 6)
                        .offset(y: min(drag, 0) + max(drag, 0) * 0.2)
                        .gesture(
                            DragGesture()
                                .onChanged { drag = $0.translation.height }
                                .onEnded { value in
                                    if value.translation.height < -30 || value.predictedEndTranslation.height < -80 { dismiss() }
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { drag = 0 }
                                }
                        )
                        .onTapGesture {
                            onTap?(current)
                            dismiss()
                        }
                        .transition(transition)
                        .id(current.id)
                }
            }
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.78), value: item?.id)
        }
        .onChange(of: item?.id) { _, id in
            guard id != nil else { return }
            startTimer()
        }
        .onAppear { if item != nil { startTimer() } }
    }

    private var transition: AnyTransition {
        if reduceMotion { return .opacity }
        if style == .island { return .scale(scale: 0.4, anchor: .top).combined(with: .opacity) }
        return .move(edge: .top).combined(with: .opacity)
    }

    private func startTimer() {
        dismissTask?.cancel()
        progress = 1
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        withAnimation(.linear(duration: max(seconds, 0.1))) { progress = 0 }
        dismissTask = Task {
            try? await Task.sleep(for: duration)
            if !Task.isCancelled { dismiss() }
        }
    }

    private func dismiss() {
        dismissTask?.cancel()
        item = nil
    }
}

private struct KitoCenterBannerModifier: ViewModifier {
    @Bindable var center: KitoNotificationCenter
    let style: KitoNotificationBannerStyle
    let duration: Duration
    let onTap: ((KitoInboxNotification) -> Void)?
    @State private var item: KitoInboxNotification?

    func body(content: Content) -> some View {
        content
            .modifier(KitoNotificationBannerModifier(item: $item, style: style, duration: duration, onTap: onTap))
            .onChange(of: center.lastForegroundEvent) { _, event in
                if let event { item = KitoInboxNotification(event) }
            }
    }
}

public extension View {
    /// Drops a banner from the top while `item` is set: it counts down and dismisses itself,
    /// swipes up to dismiss, and calls `onTap` when tapped.
    func kitoNotificationBanner(
        _ item: Binding<KitoInboxNotification?>,
        style: KitoNotificationBannerStyle = .system,
        duration: Duration = .seconds(4),
        onTap: ((KitoInboxNotification) -> Void)? = nil
    ) -> some View {
        modifier(KitoNotificationBannerModifier(item: item, style: style, duration: duration, onTap: onTap))
    }

    /// Shows an in-app banner for every notification `center` receives while the app is open.
    /// Pair it with `center.foregroundPresentation = [.list, .badge]` if you don't also want the
    /// system banner.
    func kitoNotificationBanners(
        from center: KitoNotificationCenter,
        style: KitoNotificationBannerStyle = .system,
        duration: Duration = .seconds(4),
        onTap: ((KitoInboxNotification) -> Void)? = nil
    ) -> some View {
        modifier(KitoCenterBannerModifier(center: center, style: style, duration: duration, onTap: onTap))
    }
}
