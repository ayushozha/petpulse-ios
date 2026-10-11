import SwiftData
import SwiftUI

struct ChangesView: View {
    var pet: Pet

    @Environment(Router.self) private var router
    @Query(sort: \DailyCheckIn.day) private var checkIns: [DailyCheckIn]

    var body: some View {
        let report = BaselineEngine.detect(checkIns.map(\.sample))
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                banner(report)

                if report.hasBaseline {
                    SectionTitle("What changed?")
                    VStack(spacing: 8) {
                        ForEach(report.displayMetrics) { metric in
                            MetricChangeRow(metric: metric, change: report.change(for: metric))
                                .card(radius: 12, padding: 10)
                        }
                    }

                    SectionTitle("What this could mean").padding(.top, 6)
                    Text(Narrative.meaning(report))
                        .font(.pp(14))
                        .foregroundStyle(PP.text)
                        .lineSpacing(3)
                        .padding(.horizontal, 6)

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill").font(.system(size: 18)).foregroundStyle(PP.orange)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Recommendation").font(.pp(14, .semibold)).foregroundStyle(PP.blue)
                            Text(Narrative.recommendation(report)).font(.pp(14)).foregroundStyle(PP.text).lineSpacing(3)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PP.blueSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text("PetPulse supports monitoring and triage. It does not diagnose and is not a substitute for veterinary care.")
                        .font(.pp(11))
                        .foregroundStyle(PP.subtext)
                        .padding(.horizontal, 6)

                    PrimaryButton("Create Vet Summary", systemImage: "arrow.right") {
                        router.path.append(.vetSummary)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .screen("Changes & Next Steps")
    }

    private func banner(_ report: ChangeReport) -> some View {
        let changed = report.hasChange
        let title = !report.hasBaseline ? "Still learning" : changed ? "A change was detected" : "No meaningful change detected"
        let detail = !report.hasBaseline
            ? "Add at least \(BaselineEngine.minBaselineDays + 1) daily check-ins so PetPulse can learn what is normal for \(pet.name)."
            : Narrative.headline(report, name: pet.name, possessive: pet.possessive)
        return HStack(spacing: 14) {
            Image(systemName: changed ? "exclamationmark" : report.hasBaseline ? "checkmark" : "hourglass")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(changed ? PP.orange : PP.green, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.pp(17, .semibold)).foregroundStyle(changed ? Color(hex: 0xE8590C) : Color(hex: 0x1F7A55))
                Text(detail).font(.pp(13)).foregroundStyle(PP.text)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(changed ? PP.orangeSoft : Color(hex: 0xE6F7EE), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
