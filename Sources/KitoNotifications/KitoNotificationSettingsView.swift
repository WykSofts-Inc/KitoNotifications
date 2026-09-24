//
//  KitoNotificationSettingsView.swift
//  KitoNotifications
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A notification settings screen: the system status (with a way back from "off"), one toggle
/// per channel, quiet hours on a 24-hour dial with start and end pickers, and display options.
public struct KitoNotificationSettingsView: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @Binding var preferences: KitoNotificationPreferences
    let authorization: KitoNotificationAuthorization?
    let onEnable: (() -> Void)?

    public init(_ preferences: Binding<KitoNotificationPreferences>, authorization: KitoNotificationAuthorization? = nil, onEnable: (() -> Void)? = nil) {
        self._preferences = preferences
        self.authorization = authorization
        self.onEnable = onEnable
    }

    private var animation: Animation? { reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.xl) {
                if let authorization, authorization != .authorized { statusCard(authorization) }
                section("Notify me about", footer: "\(preferences.enabledCount) of \(preferences.channels.count) on") {
                    ForEach($preferences.channels) { $channel in
                        channelRow($channel)
                        if channel.id != preferences.channels.last?.id { Divider().padding(.leading, 62) }
                    }
                }
                section("Quiet hours", footer: preferences.quietHours.summary()) {
                    quietHours
                }
                section("Display", footer: nil) {
                    VStack(alignment: .leading, spacing: theme.spacing.sm) {
                        Text("Show previews").font(theme.typography.label).foregroundStyle(theme.colors.onSurface)
                        Picker("Show previews", selection: $preferences.previews) {
                            ForEach(KitoNotificationPreferences.Previews.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    .padding(theme.spacing.lg)
                    Divider().padding(.leading, theme.spacing.lg)
                    toggleRow("Sounds", symbol: "speaker.wave.2.fill", tint: .pink, isOn: $preferences.playsSounds)
                    Divider().padding(.leading, 62)
                    toggleRow("Badges", symbol: "app.badge.fill", tint: .red, isOn: $preferences.showsBadges)
                }
            }
            .padding(theme.spacing.lg)
            .animation(animation, value: preferences)
        }
        .background(theme.colors.background.ignoresSafeArea())
    }

    // MARK: Status

    private func statusCard(_ status: KitoNotificationAuthorization) -> some View {
        let isOff = status == .denied || status == .notDetermined
        return HStack(spacing: theme.spacing.md) {
            Image(systemName: isOff ? "bell.slash.fill" : "bell.and.waves.left.and.right.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isOff ? theme.colors.danger : theme.colors.warning))
            VStack(alignment: .leading, spacing: 2) {
                Text(status == .denied ? "Notifications are off" : status == .notDetermined ? "Notifications aren't on yet" : "Delivered quietly")
                    .font(theme.typography.bodyEmphasized)
                    .foregroundStyle(theme.colors.onSurface)
                Text(status == .provisional ? "They go to Notification Centre without a sound." : "These settings apply once you turn them on.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.onSurface.opacity(0.6))
            }
            Spacer(minLength: 0)
            Button(status == .denied ? "Settings" : "Turn on") {
                if status == .denied || onEnable == nil {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                } else {
                    onEnable?()
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(theme.colors.surface)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(Capsule().fill(theme.colors.onSurface))
            .buttonStyle(.plain)
        }
        .padding(theme.spacing.lg)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill((isOff ? theme.colors.danger : theme.colors.warning).opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder((isOff ? theme.colors.danger : theme.colors.warning).opacity(0.25), lineWidth: 1))
    }

    // MARK: Channels

    private func channelRow(_ channel: Binding<KitoNotificationChannelSetting>) -> some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: channel.wrappedValue.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(channel.wrappedValue.tint.gradient))
                .saturation(channel.wrappedValue.isOn ? 1 : 0.1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(channel.wrappedValue.title).font(theme.typography.bodyEmphasized).foregroundStyle(theme.colors.onSurface)
                Text(channel.wrappedValue.subtitle).font(theme.typography.caption).foregroundStyle(theme.colors.onSurface.opacity(0.55))
            }
            Spacer(minLength: 0)
            Toggle(channel.wrappedValue.title, isOn: channel.isOn)
                .labelsHidden()
                .tint(channel.wrappedValue.tint)
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.md)
        .accessibilityElement(children: .combine)
    }

    private func toggleRow(_ title: String, symbol: String, tint: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: theme.spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.gradient))
                .accessibilityHidden(true)
            Toggle(title, isOn: isOn)
                .font(theme.typography.bodyEmphasized)
                .foregroundStyle(theme.colors.onSurface)
                .tint(theme.colors.success)
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.vertical, theme.spacing.md)
    }

    // MARK: Quiet hours

    private var quietHours: some View {
        VStack(spacing: 0) {
            toggleRow("Quiet hours", symbol: "moon.fill", tint: .indigo, isOn: $preferences.quietHours.isEnabled)
            if preferences.quietHours.isEnabled {
                Divider().padding(.leading, theme.spacing.lg)
                HStack(spacing: theme.spacing.lg) {
                    KitoNotificationQuietHoursDial(quietHours: preferences.quietHours)
                        .frame(width: 130, height: 130)
                    VStack(alignment: .leading, spacing: theme.spacing.md) {
                        timePicker("From", symbol: "moon.stars.fill", time: $preferences.quietHours.start)
                        timePicker("Until", symbol: "sun.max.fill", time: $preferences.quietHours.end)
                    }
                }
                .padding(theme.spacing.lg)
                .transition(.opacity.combined(with: .move(edge: .top)))
                Divider().padding(.leading, 62)
                toggleRow("Let time-sensitive through", symbol: "exclamationmark.circle.fill", tint: .orange, isOn: $preferences.allowsTimeSensitive)
            }
        }
    }

    private func timePicker(_ label: String, symbol: String, time: Binding<KitoQuietHours.Time>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: symbol)
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.onSurface.opacity(0.55))
            DatePicker(label, selection: Binding(get: { time.wrappedValue.date() }, set: { time.wrappedValue = KitoQuietHours.Time($0) }), displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    // MARK: Layout

    private func section<Content: View>(_ title: String, footer: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(theme.colors.onBackground.opacity(0.5))
                .padding(.horizontal, theme.spacing.xs)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(theme.colors.surface))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(theme.colors.border.opacity(0.5), lineWidth: 1))
            if let footer {
                Text(footer)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.onBackground.opacity(0.5))
                    .padding(.horizontal, theme.spacing.xs)
                    .contentTransition(.opacity)
            }
        }
    }
}

/// A 24-hour dial with the quiet window shaded, midnight at the top, and a hand at the time now.
public struct KitoNotificationQuietHoursDial: View {
    @Environment(\.kitoTheme) private var theme
    let quietHours: KitoQuietHours
    let now: Date

    public init(quietHours: KitoQuietHours, now: Date = Date()) {
        self.quietHours = quietHours
        self.now = now
    }

    private func fraction(_ time: KitoQuietHours.Time) -> CGFloat { CGFloat(time.minutesSinceMidnight) / 1_440 }

    public var body: some View {
        let start = fraction(quietHours.start)
        let length = CGFloat(quietHours.durationMinutes) / 1_440
        let nowFraction = fraction(KitoQuietHours.Time(now))
        let isQuiet = quietHours.contains(now)
        return ZStack {
            Circle().stroke(theme.colors.onSurface.opacity(0.08), lineWidth: 14)
            // Two trims so a window that crosses midnight still draws as one arc.
            Circle()
                .trim(from: start, to: min(start + length, 1))
                .stroke(LinearGradient(colors: [Color.indigo, Color.purple], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if start + length > 1 {
                Circle()
                    .trim(from: 0, to: start + length - 1)
                    .stroke(LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            ForEach([0, 6, 12, 18], id: \.self) { hour in
                Text(hour == 0 ? "00" : "\(hour)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.colors.onSurface.opacity(0.4))
                    .offset(y: -44)
                    .rotationEffect(.degrees(Double(hour) * 15))
            }
            Capsule()
                .fill(theme.colors.onSurface)
                .frame(width: 2.5, height: 40)
                .offset(y: -20)
                .rotationEffect(.degrees(Double(nowFraction) * 360))
            Circle().fill(theme.colors.onSurface).frame(width: 7, height: 7)
            Image(systemName: isQuiet ? "moon.zzz.fill" : "sun.max.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isQuiet ? Color.indigo : Color.orange)
                .offset(y: 22)
        }
        .padding(7)
        .accessibilityElement()
        .accessibilityLabel("Quiet from \(quietHours.start.label) to \(quietHours.end.label). \(isQuiet ? "Quiet now." : "")")
    }
}
