import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack(spacing: 0) {
            LogoMark(size: 78).padding(.top, 28)
            Wordmark(size: 46).padding(.top, 2)
            Text("Know your pet. Sooner.")
                .font(.pp(19, .semibold))
                .foregroundStyle(PP.teal)
                .padding(.top, 2)
            Text("Personalized pet health monitoring\nfor a happier, healthier tomorrow.")
                .font(.pp(15))
                .foregroundStyle(PP.subtext)
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            hero

            NavigationLink { ProfileView(pet: nil) } label: {
                PrimaryButtonLabel(title: "Get Started", systemImage: "arrow.right")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)

            HStack(spacing: 6) {
                Text("Because every pet deserves\na longer, healthier life")
                    .multilineTextAlignment(.center)
                Image(systemName: "heart").foregroundStyle(PP.teal)
            }
            .font(.pp(14))
            .foregroundStyle(PP.subtext)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PP.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var hero: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                Image("hero_splash")
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .mask {
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.22),
                                       .init(color: .black, location: 0.85), .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .topTrailing) {
                HStack(alignment: .bottom, spacing: 4) {
                    Text("Small\nchanges\nmake a big\ndifference")
                        .font(.handwriting(19))
                        .multilineTextAlignment(.center)
                    Image(systemName: "heart").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(PP.teal)
                .rotationEffect(.degrees(-12))
                .padding(.top, 34)
                .padding(.trailing, 22)
            }
            .padding(.vertical, 6)
    }
}
