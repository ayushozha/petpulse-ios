import SwiftData
import SwiftUI

struct MoreView: View {
    var pet: Pet

    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Query(sort: \DailyCheckIn.day) private var checkIns: [DailyCheckIn]
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                item("Pet Profile", "Name, breed, weight and medical history", "pawprint.fill") { router.path.append(.profile) }
                item("Changes & Next Steps", "What is different from \(pet.name)'s normal", "waveform.path.ecg") { router.path.append(.changes) }
                item("Vet-ready Summary", "A structured report to share with your vet", "doc.text.fill") { router.path.append(.vetSummary) }

                SectionTitle("Demo").padding(.top, 12)
                item("Simulate a 3-day change", "Dry food down 40% and activity down 30%", "exclamationmark.triangle.fill", tint: PP.orange) {
                    DemoSeeder.simulateChange(in: context, existing: checkIns)
                    router.path = [.changes]
                }
                item("Reload healthy history", "Replace all check-ins with 28 normal days", "arrow.counterclockwise") {
                    DemoSeeder.deleteHistory(in: context)
                    DemoSeeder.seedHealthyHistory(in: context, weight: pet.weightKg ?? 4.2)
                    router.path = []
                }
                item("Reset all data", "Delete the pet and every check-in", "trash.fill", tint: PP.red) { confirmReset = true }

                Text("PetPulse supports early change detection, monitoring and triage. It does not diagnose and does not replace your veterinarian. All data stays on this device.")
                    .font(.pp(12))
                    .foregroundStyle(PP.subtext)
                    .padding(.top, 14)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .screen("More")
        .confirmationDialog("Delete \(pet.name) and all check-ins?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                router.path = []
                DemoSeeder.deleteHistory(in: context)
                context.delete(pet)
            }
        }
    }

    private func item(_ title: String, _ subtitle: String, _ symbol: String, tint: Color = PP.teal,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.pp(15, .semibold)).foregroundStyle(PP.navy)
                    Text(subtitle).font(.pp(12)).foregroundStyle(PP.subtext).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(PP.subtext)
            }
            .card(padding: 12)
        }
        .buttonStyle(.plain)
    }
}
