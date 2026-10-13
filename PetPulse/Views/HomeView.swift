import SwiftData
import SwiftUI

struct HomeView: View {
    var pet: Pet

    @Environment(Router.self) private var router
    @Query(sort: \DailyCheckIn.day) private var checkIns: [DailyCheckIn]

    private var report: ChangeReport { BaselineEngine.detect(checkIns.map(\.sample)) }
    private var doneToday: Bool { checkIns.last.map { Calendar.current.isDateInToday($0.day) } ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Text(greeting).font(.pp(24, .bold)).foregroundStyle(PP.navy).padding(.top, 14)
                Text("Here's \(pet.name)'s health today.").font(.pp(15)).foregroundStyle(PP.subtext).padding(.top, 2)
            }
            .padding(.horizontal, 22)

            hero

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SectionTitle("Today's Check-in")
                    Spacer()
                    Label(Date.now.mediumLabel, systemImage: "calendar")
                        .labelStyle(TrailingIconLabelStyle())
                        .font(.pp(13))
                        .foregroundStyle(PP.subtext)
                }
                HStack {
                    todayItem("Food", kind: .metric(.wetFood))
                    Spacer()
                    todayItem("Water", kind: .metric(.water))
                    Spacer()
                    todayItem("Stool", kind: .metric(.stool))
                    Spacer()
                    todayItem("Activity", kind: .metric(.activity))
                }
                .padding(.horizontal, 4)
                VStack(spacing: 10) {
                    PrimaryButton(doneToday ? "Edit Today's Check-in" : "Start Daily Check-in", systemImage: "arrow.right") {
                        router.path.append(.checkIn)
                    }
                    SecondaryButton("Speak Your Check-in", leadingImage: "mic.fill") {
                        router.path.append(.voiceCheckIn)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .background(PP.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning!"
        case 12..<17: "Good afternoon!"
        default: "Good evening!"
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            LogoMark(size: 30)
            Wordmark(size: 22)
            Spacer()
            Image(systemName: "bell").font(.system(size: 19)).foregroundStyle(PP.navy).padding(.trailing, 10)
            Button { router.path.append(.profile) } label: {
                PhotoView(ref: pet.avatar)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PP.stroke, lineWidth: 1))
            }
            .accessibilityLabel("Pet profile")
        }
        .padding(.top, 6)
    }

    private var hero: some View {
        Color.clear
            .frame(height: 230)
            .overlay {
                Image("hero_home").resizable().scaledToFill()
            }
            .clipped()
            .mask {
                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.2),
                                       .init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .topTrailing) {
                HStack(alignment: .bottom, spacing: 3) {
                    Text("A healthier\ntomorrow\ntogether").font(.handwriting(17)).multilineTextAlignment(.center)
                    Image(systemName: "heart").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(PP.teal)
                .rotationEffect(.degrees(-8))
                .padding(.top, 20)
                .padding(.trailing, 20)
            }
            .overlay(alignment: .bottom) { statusCard.padding(.horizontal, 18).offset(y: 22) }
            .padding(.bottom, 22)
    }

    private var statusCard: some View {
        let changed = report.hasChange
        let title = !report.hasBaseline ? "Learning \(pet.name)'s baseline" : changed ? "A change was detected" : "No meaningful change detected"
        let subtitle = !report.hasBaseline
            ? "Keep adding daily check-ins."
            : changed ? Narrative.headline(report, name: pet.name, possessive: pet.possessive)
            : "\(pet.name) seems to be doing well today!"
        let color = changed ? PP.orange : PP.green
        return Button { router.path.append(.changes) } label: {
            HStack(spacing: 12) {
                Image(systemName: changed ? "exclamationmark" : "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(color, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.pp(16, .semibold)).foregroundStyle(changed ? PP.orange : Color(hex: 0x1F7A55))
                    Text(subtitle).font(.pp(12)).foregroundStyle(PP.subtext).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
            }
            .padding(14)
            .background(changed ? PP.orangeSoft : Color(hex: 0xE6F7EE), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white, lineWidth: 2))
            .shadow(color: PP.navy.opacity(0.08), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func todayItem(_ label: String, kind: IconKind) -> some View {
        VStack(spacing: 8) {
            IconBadge(kind: kind, size: 52)
                .overlay(alignment: .bottomTrailing) {
                    if doneToday {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(.white, PP.green)
                            .offset(x: 3, y: 3)
                    }
                }
            Text(label).font(.pp(12)).foregroundStyle(PP.text)
        }
    }

    private var tabBar: some View {
        HStack(alignment: .bottom) {
            tab("Home", "house.fill", active: true) {}
            tab("Baseline", "chart.xyaxis.line") { router.path.append(.baseline) }
            Button { router.path.append(.checkIn) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(PP.buttonGradient, in: Circle())
                    .shadow(color: PP.teal.opacity(0.35), radius: 6, y: 3)
            }
            .accessibilityLabel("New check-in")
            .frame(maxWidth: .infinity)
            tab("Timeline", "clock") { router.path.append(.timeline) }
            tab("More", "ellipsis") { router.path.append(.more) }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color.white.shadow(.drop(color: PP.navy.opacity(0.06), radius: 8, y: -2)), ignoresSafeAreaEdges: .bottom)
    }

    private func tab(_ title: String, _ symbol: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 19)).frame(height: 24)
                Text(title).font(.pp(11, active ? .semibold : .regular))
            }
            .foregroundStyle(active ? PP.teal : PP.subtext)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Label with the icon after the text, as in "Oct 10, 2026 📅".
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.title
            configuration.icon
        }
    }
}
