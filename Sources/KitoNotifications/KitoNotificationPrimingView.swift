//
//  KitoNotificationPrimingView.swift
//  KitoNotifications
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A full-screen "turn on notifications" page to show before the system prompt: a stack of
/// sample notifications floating over a glowing bell, what the person gets, and three choices —
/// turn on, deliver quietly (provisional, no prompt at all) or not now. If notifications are
/// already off it offers Settings instead.
public struct KitoNotificationPrimingView: View {
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    let title: String
    let message: String
    let benefits: [(symbol: String, text: String)]
    let samples: [KitoInboxNotification]
    let allowsProvisional: Bool
    let authorize: (_ provisional: Bool) async -> KitoNotificationAuthorization
    let currentStatus: () async -> KitoNotificationAuthorization
    let onFinish: (KitoNotificationAuthorization) -> Void

    @State private var status: KitoNotificationAuthorization = .notDetermined
    @State private var isAsking = false
    @State private var appeared = false
    @State private var float = false

    public init(
        title: String = "Never miss what matters",
        message: String = "Know the moment your order ships, money lands, or someone replies. You choose what we send.",
        benefits: [(symbol: String, text: String)] = [
            ("shippingbox.fill", "Delivery updates, live"),
            ("creditcard.fill", "Payments and receipts"),
            ("moon.fill", "Quiet hours you control"),
        ],
        samples: [KitoInboxNotification] = KitoNotificationPrimingView.defaultSamples,
        allowsProvisional: Bool = true,
        authorize: @escaping (_ provisional: Bool) async -> KitoNotificationAuthorization = { await KitoNotificationCenter.shared.requestAuthorization(provisional: $0) },
        currentStatus: @escaping () async -> KitoNotificationAuthorization = {
            await KitoNotificationCenter.shared.refreshAuthorization()
            return KitoNotificationCenter.shared.authorization
        },
        onFinish: @escaping (KitoNotificationAuthorization) -> Void
    ) {
        self.title = title
        self.message = message
        self.benefits = benefits
        self.samples = samples
        self.allowsProvisional = allowsProvisional
        self.authorize = authorize
        self.currentStatus = currentStatus
        self.onFinish = onFinish
    }

    public static let defaultSamples: [KitoInboxNotification] = [
        KitoInboxNotification(kind: .order, title: "Your rider is 3 min away", body: "Brian is on a red boda — have KSh 1,540 ready.", avatar: .initials("BK", Color(red: 0.98, green: 0.55, blue: 0.10))),
        KitoInboxNotification(kind: .payment, title: "KSh 12,000 received", body: "From Amina Wanjiru · M-Pesa", avatar: .symbol("arrow.down.left", Color(red: 0.12, green: 0.68, blue: 0.42))),
        KitoInboxNotification(kind: .message, title: "Grace Achieng", body: "Tupatane Java House saa nane?", avatar: .initials("GA", Color(red: 0.58, green: 0.36, blue: 0.96))),
    ]

    public var body: some View {
        VStack(spacing: 0) {
            illustration
                .frame(height: 290)
                .frame(maxWidth: .infinity)
            VStack(spacing: theme.spacing.md) {
                Text(status == .denied ? "Notifications are off" : title)
                    .font(theme.typography.displayMedium.weight(.bold))
                    .foregroundStyle(theme.colors.onBackground)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                Text(status == .denied ? "Turn them on in Settings › Notifications to get delivery and payment updates." : message)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.onBackground.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if status != .denied {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(benefits.enumerated()), id: \.offset) { _, benefit in
                            HStack(spacing: 12) {
                                Image(systemName: benefit.symbol)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(theme.colors.primary)
                                    .frame(width: 32, height: 32)
                                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.colors.primary.opacity(0.12)))
                                Text(benefit.text)
                                    .font(theme.typography.label)
                                    .foregroundStyle(theme.colors.onBackground.opacity(0.85))
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.top, theme.spacing.xs)
                }
            }
            .padding(.horizontal, theme.spacing.xl)
            Spacer(minLength: theme.spacing.md)
            buttons
                .padding(.horizontal, theme.spacing.xl)
                .padding(.bottom, theme.spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [theme.colors.primary.opacity(0.16), theme.colors.background, theme.colors.background], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .task { status = await currentStatus() }
        .onAppear {
            if reduceMotion { appeared = true; return }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) { appeared = true }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { float = true }
        }
    }

    private var illustration: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [theme.colors.primary.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 150))
                .frame(width: 300, height: 300)
                .blur(radius: 10)
            Image(systemName: status == .denied ? "bell.slash.fill" : "bell.badge.fill")
                .font(.system(size: 64, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(theme.colors.danger, theme.colors.primary)
                .rotationEffect(.degrees(float ? 6 : -6), anchor: .top)
                .offset(y: -86)
                .opacity(0.9)
            ForEach(Array(samples.prefix(3).enumerated()), id: \.element.id) { index, sample in
                KitoNotificationBanner(sample, style: .system, appName: nil)
                    .frame(width: 300)
                    .scaleEffect(1 - CGFloat(index) * 0.06)
                    .offset(y: CGFloat(index) * 22 + (float ? -4 : 4) * CGFloat(index + 1) / 2 + 30)
                    .opacity(appeared ? 1 - Double(index) * 0.25 : 0)
                    .offset(y: appeared ? 0 : -40)
                    .zIndex(Double(3 - index))
                    .animation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.75).delay(Double(index) * 0.12), value: appeared)
            }
            .saturation(status == .denied ? 0 : 1)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var buttons: some View {
        VStack(spacing: 8) {
            if status == .denied {
                primaryButton("Open Settings", symbol: "gearshape.fill") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                secondaryButton("Not now") { onFinish(status) }
            } else if status == .authorized || status == .provisional {
                primaryButton(status == .authorized ? "You're all set" : "Delivered quietly — continue", symbol: "checkmark") { onFinish(status) }
            } else {
                primaryButton("Turn on notifications", symbol: "bell.fill") { ask(provisional: false) }
                if allowsProvisional {
                    secondaryButton("Deliver quietly instead") { ask(provisional: true) }
                }
                secondaryButton("Not now") { onFinish(status) }
            }
        }
        .disabled(isAsking)
    }

    private func primaryButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Label(title, systemImage: symbol).opacity(isAsking ? 0 : 1)
                if isAsking { ProgressView().tint(theme.colors.background) }
            }
            .font(theme.typography.button)
            .foregroundStyle(theme.colors.background)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule().fill(theme.colors.onBackground))
        }
        .buttonStyle(KitoPressableStyle())
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(theme.typography.label)
            .foregroundStyle(theme.colors.onBackground.opacity(0.65))
            .frame(maxWidth: .infinity, minHeight: 40)
            .buttonStyle(.plain)
    }

    private func ask(provisional: Bool) {
        isAsking = true
        Task {
            let result = await authorize(provisional)
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8)) {
                status = result
                isAsking = false
            }
            // A "no" stays on screen with the Settings path; anything else moves on.
            guard result != .denied else { return }
            try? await Task.sleep(for: .milliseconds(700))
            onFinish(result)
        }
    }
}

/// Dips a little when pressed.
struct KitoPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
