import SwiftData
import SwiftUI

struct VetSummaryView: View {
    var pet: Pet

    @Environment(\.modelContext) private var context
    @Query(sort: \DailyCheckIn.day) private var checkIns: [DailyCheckIn]
    @Query private var events: [TimelineEvent]

    @State private var concern = ""
    @State private var pdfURL: URL?
    @State private var loaded = false

    private var report: ChangeReport { BaselineEngine.detect(checkIns.map(\.sample)) }
    private var photos: [PhotoRef] { checkIns.suffix(14).reversed().flatMap(\.photos) }

    var body: some View {
        let report = self.report
        let photos = self.photos
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VetSummaryContent(pet: pet, report: report, photos: photos, concern: concern) {
                    TextField("Describe what worries you", text: $concern, axis: .vertical)
                        .font(.pp(14))
                        .foregroundStyle(PP.text)
                        .lineLimit(2...5)
                }
                shareButton {
                    PrimaryButtonLabel(title: "Share Report", leadingImage: "square.and.arrow.up")
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .screen("Vet-ready Summary") {
            shareButton { Text("Share").font(.pp(15, .semibold)).foregroundStyle(PP.teal) }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            concern = Narrative.ownerConcern(report)
            renderPDF()
        }
        .onChange(of: concern) { renderPDF() }
    }

    @ViewBuilder
    private func shareButton<L: View>(@ViewBuilder label: () -> L) -> some View {
        if let pdfURL {
            ShareLink(item: pdfURL, preview: SharePreview("\(pet.name) – vet summary")) { label() }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { _ in logExport() })
        } else {
            label().opacity(0.5)
        }
    }

    private func renderPDF() {
        let page = VetSummaryContent(pet: pet, report: report, photos: photos, concern: concern, forPrint: true) {
            Text(concern).font(.pp(14)).foregroundStyle(PP.text)
        }
        .padding(28)
        .frame(width: 612)
        .background(.white)
        pdfURL = VetSummaryPDF.write(page, name: "\(pet.name)-vet-summary.pdf")
    }

    /// Records the export on today's timeline, once per day.
    private func logExport() {
        let today = Calendar.current.startOfDay(for: .now)
        guard !events.contains(where: { $0.day == today }) else { return }
        context.insert(TimelineEvent(day: today, title: "Vet summary exported", subtitle: "Shared with your veterinarian"))
    }
}

/// The summary itself, shared by the screen and the exported PDF.
struct VetSummaryContent<Concern: View>: View {
    var pet: Pet
    var report: ChangeReport
    var photos: [PhotoRef]
    var concern: String
    var forPrint = false
    @ViewBuilder var concernField: Concern

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if forPrint {
                HStack(spacing: 8) {
                    LogoMark(size: 26)
                    Wordmark(size: 20)
                    Spacer()
                    Text("Vet-ready summary · \(Date.now.mediumLabel)").font(.pp(12)).foregroundStyle(PP.subtext)
                }
            }

            HStack(spacing: 14) {
                PhotoTile(ref: pet.avatar, size: 72, radius: 14)
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name).font(.pp(20, .bold)).foregroundStyle(PP.navy)
                    Text("\(pet.ageLabel)  ·  \(pet.sexLabel)  ·  \(pet.neuterLabel)")
                    Text(pet.breed + (pet.weightKg.map { "  ·  " + String(format: "%g", $0) + " kg" } ?? ""))
                }
                .font(.pp(13))
                .foregroundStyle(PP.subtext)
            }
            .card()

            SectionTitle("Owner's Concern")
            concernField.card(radius: 12, padding: 12)

            if !pet.medicalHistory.isEmpty {
                SectionTitle("Medical History")
                Text(pet.medicalHistory).font(.pp(14)).foregroundStyle(PP.text).card(radius: 12, padding: 12)
            }

            SectionTitle("Key Changes")
            VStack(spacing: 10) {
                if report.hasBaseline {
                    ForEach(report.displayMetrics) { metric in
                        MetricChangeRow(metric: metric, change: report.change(for: metric), iconSize: 26)
                    }
                } else {
                    Text("Not enough check-ins yet to establish a baseline.").font(.pp(13)).foregroundStyle(PP.subtext)
                }
            }
            .card(radius: 12, padding: 12)

            SectionTitle("Timeline")
            VStack(alignment: .leading, spacing: 4) {
                Text(rangeLabel).font(.pp(14, .semibold)).foregroundStyle(PP.navy)
                Text(Narrative.timelineSummary(report)).font(.pp(13)).foregroundStyle(PP.text)
            }
            .card(radius: 12, padding: 12)

            if !photos.isEmpty {
                SectionTitle("Photos")
                photoStrip
            }

            if forPrint {
                Text("Generated by PetPulse from owner-recorded daily check-ins. Changes are relative to this pet's own baseline. This is not a diagnosis.")
                    .font(.pp(10))
                    .foregroundStyle(PP.subtext)
            }
        }
    }

    private var rangeLabel: String {
        guard let end = report.endDay else { return Date.now.mediumLabel }
        guard let start = report.startDay, start != end else { return end.mediumLabel }
        return "\(start.shortLabel) – \(end.mediumLabel)"
    }

    private var photoStrip: some View {
        let extra = photos.count - 3
        return HStack(spacing: 8) {
            ForEach(Array(photos.prefix(extra > 0 ? 3 : 4).enumerated()), id: \.offset) { item in
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay { PhotoView(ref: item.element) }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if extra > 0 {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay { PhotoView(ref: photos[3]) }
                    .overlay { Color(hex: 0x52606D, alpha: 0.75) }
                    .overlay { Text("+\(extra)").font(.pp(18, .semibold)).foregroundStyle(.white) }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxHeight: 84)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum VetSummaryPDF {
    /// Renders a SwiftUI view as a single-page vector PDF in the temporary directory.
    @MainActor
    static func write(_ view: some View, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let renderer = ImageRenderer(content: view)
        var written = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            written = true
        }
        return written ? url : nil
    }
}
