import SwiftUI

struct OnboardingView: View {

    @Binding var isPresented: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "moon.stars.fill",
            title: "Build Better Routines",
            body: "Create step-by-step routines for any part of your day — morning, bedtime, workout, and more.",
            tint: .indigo
        ),
        OnboardingPage(
            icon: "timer",
            title: "Stay on Track",
            body: "Each step has a timer that counts down and alerts you when time's up — even if your phone is on silent.",
            tint: .orange
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "Never Miss a Start",
            body: "Schedule routines and get a heads-up notification 5 minutes before they begin.",
            tint: .blue
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: 12) {
                if currentPage < pages.count - 1 {
                    Button {
                        withAnimation { currentPage += 1 }
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Skip") {
                        isPresented = false
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Button {
                        isPresented = false
                    } label: {
                        Text("Get Started")
                            .frame(maxWidth: .infinity)
                            .font(.body.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            .padding(.top, 16)
        }
    }
}

// MARK: - Supporting types

struct OnboardingPage {
    let icon: String
    let title: String
    let body: String
    let tint: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: page.icon)
                .font(.system(size: 72))
                .foregroundStyle(page.tint)
                .symbolRenderingMode(.hierarchical)
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
